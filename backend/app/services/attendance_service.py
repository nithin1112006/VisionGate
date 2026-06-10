"""Attendance service for core business logic - marking, CL management, leave processing."""
from datetime import datetime, date, timedelta
from typing import Optional, Dict, Any, List
import logging
import asyncio
import numpy as np
from concurrent.futures import ThreadPoolExecutor

from app.database.repositories.attendance_repository import AttendanceRepository
from app.database.repositories.user_repository import UserRepository
from app.database.repositories.face_repository import FaceRepository
from app.database.repositories.geo_repository import GeoRepository
from app.api.schemas.attendance import AttendanceRecord, DailyStatusResponse
from app.api.schemas.leave import CLBalanceResponse
from app.config import settings

logger = logging.getLogger(__name__)

executor = ThreadPoolExecutor(max_workers=4)


class FaceNotFoundError(Exception):
    """Raised when no face is detected in the image."""
    pass


class LowConfidenceError(Exception):
    """Raised when face confidence is below threshold."""
    pass


class AttendanceService:
    def __init__(
        self,
        attendance_repo: AttendanceRepository,
        user_repo: UserRepository,
        face_repo: FaceRepository,
        geo_repo: GeoRepository,
        leave_repo: Optional[Any] = None
    ):
        self.attendance_repo = attendance_repo
        self.user_repo = user_repo
        self.face_repo = face_repo
        self.geo_repo = geo_repo
        self.leave_repo = leave_repo
        self.logger = logger

    async def mark_attendance_secure(
        self,
        reg_no: str,
        image_bytes: bytes,
        client_platform: str = None,
        client_lat: float = None,
        client_lng: float = None
    ) -> Dict[str, Any]:
        """
        Main attendance marking flow:
        1. Extract face embedding from image
        2. Verify identity against registered face (pgvector similarity search)
        3. Record attendance in DB
        4. Update daily status
        5. Log audit event
        """
        try:
            query_embedding = await self._extract_face_embedding(image_bytes)
        except FaceNotFoundError as e:
            return {"success": False, "error": str(e), "code": "NO_FACE"}
        except Exception as e:
            self.logger.error(f"Face extraction error for {reg_no}: {e}")
            return {"success": False, "error": "Failed to process image", "code": "PROCESSING_ERROR"}

        verified, confidence, reason = await self._verify_identity(reg_no, query_embedding)
        if not verified:
            return {
                "success": False,
                "error": reason,
                "code": "FACE_MISMATCH",
                "confidence": confidence
            }

        user = await self.user_repo.get_by_reg_no(reg_no)
        if not user:
            return {"success": False, "error": "User not found", "code": "USER_NOT_FOUND"}

        now = datetime.now()
        try:
            attendance_id = await self.attendance_repo.insert_attendance(
                reg_no=reg_no,
                name=user.name,
                dept=user.dept,
                timestamp=now,
                status="present"
            )
        except Exception as e:
            self.logger.error(f"DB error marking attendance: {e}")
            return {"success": False, "error": "Database error", "code": "DB_ERROR"}

        try:
            await self._sync_daily_status(reg_no, now.date())
        except Exception as e:
            self.logger.warning(f"Failed to sync daily status: {e}")

        self.logger.info(
            "attendance_marked",
            extra={"reg_no": reg_no, "confidence": confidence, "attendance_id": attendance_id}
        )

        return {
            "success": True,
            "message": "Attendance marked successfully",
            "data": {
                "attendance_id": attendance_id,
                "timestamp": now.isoformat(),
                "user": {"reg_no": reg_no, "name": user.name, "dept": user.dept},
                "confidence": confidence
            }
        }

    async def _extract_face_embedding(self, image_bytes: bytes) -> bytes:
        """Extract face embedding from image using face recognition model."""
        loop = asyncio.get_event_loop()
        
        def _extract_sync():
            import cv2
            nparr = np.frombuffer(image_bytes, np.uint8)
            img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
            if img is None:
                raise FaceNotFoundError("Could not decode image")
            
            try:
                from insightface.app import FaceAnalysis
                app = FaceAnalysis(name="buffalo_l", providers=["CPUExecutionProvider"])
                app.prepare(ctx_id=0, det_thresh=0.5)
                faces = app.get(img)
            except Exception:
                raise FaceNotFoundError("Face detection failed")
            
            if not faces:
                raise FaceNotFoundError("No face detected in image")
            
            embedding = faces[0].embedding
            return embedding.astype(np.float32).tobytes()
        
        return await loop.run_in_executor(executor, _extract_sync)

    async def _verify_identity(self, reg_no: str, query_embedding: bytes) -> tuple:
        """Verify face identity against registered user. Returns (verified, confidence, reason)."""
        matches = await self.face_repo.search_similar_faces(
            query_embedding,
            limit=5,
            threshold=settings.FACE_MIN_COSINE_SIMILARITY
        )
        
        for match_reg_no, name, dept, role, similarity in matches:
            if match_reg_no.lower() == reg_no.lower():
                if similarity >= settings.FACE_CONFIDENCE_THRESHOLD:
                    return True, similarity, "Identity verified"
                return False, similarity, f"Low confidence match ({similarity:.2f})"
        
        return False, 0.0, "Face not recognized"

    async def _sync_daily_status(self, reg_no: str, for_date: date) -> None:
        """Sync daily attendance status for user."""
        from app.database.connection import db_pool
        async with db_pool.pool.acquire() as conn:
            await conn.execute(
                """
                INSERT INTO daily_attendance_status (reg_no, date, status, last_updated)
                VALUES ($1, $2, 'present', NOW())
                ON CONFLICT (reg_no, date) 
                DO UPDATE SET status = 'present', last_updated = NOW()
                """,
                reg_no, for_date
            )

    async def get_attendance_history(self, reg_no: str, limit: int = 20) -> List[AttendanceRecord]:
        """Get recent attendance history for a user."""
        records = await self.attendance_repo.get_recent_attendance(reg_no, limit)
        return [AttendanceRecord(**r) for r in records]

    async def get_daily_status(self, reg_no: str, for_date: date = None) -> DailyStatusResponse:
        """Get daily attendance status for a user."""
        if for_date is None:
            for_date = date.today()
        
        status = await self._get_today_attendance(reg_no, for_date)
        if not status:
            status = {"status": "absent", "leave_type": None}
        
        cl_balance = None
        if self.leave_repo:
            cl_balance = await self.leave_repo.get_cl_balance(reg_no)
        
        return DailyStatusResponse(
            date=for_date,
            status=status["status"],
            leave_type=status.get("leave_type"),
            cl_balance=cl_balance
        )

    async def _get_today_attendance(self, reg_no: str, for_date: date) -> Optional[Dict]:
        """Get attendance status for a specific date."""
        from app.database.connection import db_pool
        async with db_pool.pool.acquire() as conn:
            row = await conn.fetchrow(
                """
                SELECT status, leave_type FROM daily_attendance_status
                WHERE reg_no = $1 AND date = $2
                """,
                reg_no, for_date
            )
            if row:
                return {"status": row["status"], "leave_type": row["leave_type"]}
            return None

    async def process_cl_deduction(self, reg_no: str, for_date: date) -> Dict[str, Any]:
        """Process CL deduction for a leave day."""
        if not self.leave_repo:
            return {"success": False, "error": "Leave repository not configured"}
        
        try:
            result = await self.leave_repo.deduct_cl(reg_no, for_date)
            return {"success": True, **result}
        except Exception as e:
            self.logger.error(f"CL deduction error for {reg_no}: {e}")
            return {"success": False, "error": str(e)}

    async def bulk_mark_attendance(self, records: List[Dict]) -> Dict[str, Any]:
        """Bulk mark attendance for multiple users."""
        success_count = 0
        failed = []
        
        for record in records:
            result = await self.mark_attendance_secure(
                reg_no=record["reg_no"],
                image_bytes=record["image_bytes"],
                client_platform=record.get("platform"),
                client_lat=record.get("lat"),
                client_lng=record.get("lng")
            )
            if result.get("success"):
                success_count += 1
            else:
                failed.append({"reg_no": record["reg_no"], "error": result.get("error")})
        
        return {
            "success": True,
            "total": len(records),
            "successful": success_count,
            "failed": failed
        }