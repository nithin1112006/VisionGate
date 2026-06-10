from datetime import datetime, date
from typing import Optional, List, Literal
from pydantic import BaseModel, Field, ConfigDict, field_validator

# Test minimal module
class Coordinates(BaseModel):
    """GPS coordinates."""
    latitude: float = Field(..., ge=-90, le=90, description="Latitude coordinate", examples=[13.0827])
    longitude: float = Field(..., ge=-180, le=180, description="Longitude coordinate", examples=[80.2707])

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "latitude": 13.0827,
                    "longitude": 80.2707
                }
            ]
        }
    )

class AttendanceMarkRequest(BaseModel):
    """Attendance marking request."""
    reg_no: str = Field(..., min_length=1, max_length=50, description="User registration number")
    client_lat: Optional[float] = Field(None, ge=-90, le=90, description="Client GPS latitude")
    client_lng: Optional[float] = Field(None, ge=-180, le=180, description="Client GPS longitude")
    client_platform: Optional[Literal["web", "mobile"]] = Field(None, description="Client platform type")

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "reg_no": "2020CS001",
                    "client_lat": 13.0827,
                    "client_lng": 80.2707,
                    "client_platform": "web"
                }
            ]
        }
    )

    @field_validator("reg_no", mode="before")
    @classmethod
    def strip_strings(cls, v: str) -> str:
        if isinstance(v, str):
            return v.strip()
        return v

class AttendanceMarkResponse(BaseModel):
    """Attendance marking response."""
    attendance_id: int = Field(..., description="Unique attendance record ID")
    timestamp: datetime = Field(..., description="Attendance timestamp (UTC)")
    confidence: float = Field(..., ge=0, le=1, description="Face recognition confidence score")
    mode: Literal["insightface", "fallback"] = Field(..., description="Detection method used")

    model_config = ConfigDict(
        from_attributes=True,
        json_schema_extra={
            "examples": [
                {
                    "attendance_id": 123,
                    "timestamp": "2024-01-15T14:30:00Z",
                    "confidence": 0.92,
                    "mode": "insightface"
                }
            ]
        }
    )

class AttendanceRecord(BaseModel):
    """Single attendance record."""
    id: int = Field(..., description="Attendance record ID")
    reg_no: str = Field(..., description="User registration number")
    name: str = Field(..., description="User full name")
    dept: str = Field(..., description="Department code")
    timestamp: datetime = Field(..., description="Check-in timestamp")
    error_message: Optional[str] = Field(None, description="Error message if any")

    model_config = ConfigDict(
        from_attributes=True,
        json_schema_extra={
            "examples": [
                {
                    "id": 1,
                    "reg_no": "2020CS001",
                    "name": "John Doe",
                    "dept": "CSE",
                    "timestamp": "2024-01-15T09:00:00Z",
                    "error_message": None
                }
            ]
        }
    )

class DailyStatusResponse(BaseModel):
    """Daily attendance status for a user."""
    date: date = Field(..., description="Date of status")
    status: Literal["present", "absent", "half_day", "leave", "holiday"] = Field(..., description="Attendance status")
    leave_type: Optional[Literal["casual", "earned", "od", "sick"]] = Field(None, description="Leave type if on leave")
    leave_request_id: Optional[int] = Field(None, description="Associated leave request ID")

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "date": "2024-01-15",
                    "status": "present",
                    "leave_type": None,
                    "leave_request_id": None
                }
            ]
        }
    )
