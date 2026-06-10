"""Dataclass models for all database tables."""
from dataclasses import dataclass
from datetime import datetime, date, time
from decimal import Decimal
from typing import Optional, List, BinaryIO
import uuid


@dataclass
class User:
    """User table model."""
    id: int
    reg_no: str
    username: str
    password_hash: str
    name: str
    dept: str
    role: str
    is_active: bool
    created_at: datetime
    updated_at: datetime
    face_embedding: Optional[bytes] = None


@dataclass
class OtherStaff:
    """Other staff table model."""
    id: int
    name: str
    dept: str
    contact_no: str
    is_active: bool
    created_at: datetime
    updated_at: datetime


@dataclass
class Attendance:
    """Attendance table model."""
    id: int
    reg_no: str
    name: str
    dept: str
    timestamp: datetime
    status: str  # 'IN', 'OUT'
    location: Optional[str] = None
    device_id: Optional[str] = None


@dataclass
class OtherStaffAttendance:
    """Other staff attendance table model."""
    id: int
    staff_id: int
    timestamp: datetime
    status: str  # 'IN', 'OUT'
    location: Optional[str] = None
    device_id: Optional[str] = None


@dataclass
class DailyAttendanceStatus:
    """Daily attendance status table model."""
    id: int
    reg_no: str
    date: date
    status: str  # 'PRESENT', 'ABSENT', 'LEAVE', 'HOLIDAY'
    in_time: Optional[time] = None
    out_time: Optional[time] = None
    total_hours: Optional[Decimal] = None
    updated_at: datetime


@dataclass
class CasualLeave:
    """Casual leave table model."""
    id: int
    reg_no: str
    leave_date: date
    reason: str
    approved: bool
    approved_by: Optional[str] = None
    approved_at: Optional[datetime] = None
    created_at: datetime


@dataclass
class LeaveRequest:
    """Leave requests table model."""
    id: int
    reg_no: str
    leave_type: str  # 'CASUAL', 'SICK', 'EARNED', etc.
    start_date: date
    end_date: date
    reason: str
    status: str  # 'PENDING', 'APPROVED', 'REJECTED'
    approved_by: Optional[str] = None
    approved_at: Optional[datetime] = None
    created_at: datetime
    updated_at: datetime


@dataclass
class FaceEmbeddingSample:
    """Face embedding samples table model."""
    id: int
    reg_no: str
    source_table: str  # 'users', 'other_staff'
    embedding: bytes  # 512-dim vector
    sample_type: str  # 'ENROLLMENT', 'UPDATE'
    confidence: float
    created_at: datetime


@dataclass
class FaceTrainingRun:
    """Face training runs table model."""
    id: int
    started_at: datetime
    completed_at: Optional[datetime] = None
    status: str  # 'PENDING', 'RUNNING', 'COMPLETED', 'FAILED'
    total_samples: int = 0
    trained_embeddings: int = 0
    error_message: Optional[str] = None


@dataclass
class UserLocationLog:
    """User location logs table model."""
    id: int
    reg_no: str
    timestamp: datetime
    latitude: Decimal
    longitude: Decimal
    accuracy: Optional[Decimal] = None
    location_name: Optional[str] = None


@dataclass
class UserLatestLocation:
    """User latest locations table model."""
    reg_no: str
    latitude: Decimal
    longitude: Decimal
    timestamp: datetime
    location_name: Optional[str] = None
    accuracy: Optional[Decimal] = None


@dataclass
class GeoFenceCoordinateV2:
    """Geo fence coordinates v2 table model."""
    id: int
    fence_name: str
    latitude: Decimal
    longitude: Decimal
    radius_meters: int
    is_active: bool
    created_at: datetime
    updated_at: datetime


@dataclass
class AttendanceDurationSettings:
    """Attendance duration settings table model."""
    id: int
    dept: str
    min_hours: Decimal
    max_hours: Decimal
    grace_period_minutes: int
    effective_from: date
    effective_to: Optional[date] = None
    created_at: datetime
    updated_at: datetime


@dataclass
class AdminNotification:
    """Admin notifications table model."""
    id: int
    title: str
    message: str
    is_read: bool
    created_at: datetime
    updated_at: datetime


@dataclass
class LeaveRequestAuditLog:
    """Leave request audit log table model."""
    id: int
    leave_request_id: int
    action: str  # 'APPROVED', 'REJECTED', 'CANCELLED'
    performed_by: str
    remarks: Optional[str] = None
    timestamp: datetime


@dataclass
class FaceReregisterRequest:
    """Face reregister requests table model."""
    id: int
    reg_no: str
    requested_at: datetime
    reason: str
    status: str  # 'PENDING', 'APPROVED', 'REJECTED'
    processed_by: Optional[str] = None
    processed_at: Optional[datetime] = None