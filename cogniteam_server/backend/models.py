# Pydantic models for data validation and serialization
from pydantic import BaseModel, Field, EmailStr
from typing import Optional, List
from datetime import date
import uuid

class UserBase(BaseModel):
    name: str
    sex: str
    birth_date: date
    mbti: Optional[str] = None
    company: Optional[str] = None
    division: Optional[str] = None
    department: Optional[str] = None
    section: Optional[str] = None
    role: Optional[str] = None

class UserCreate(UserBase):
    email: EmailStr
    password: str

class User(UserBase):
    user_id: str = Field(..., description="Unique identifier for the user")
    email: EmailStr = Field(..., description="User's email address")
    display_name: str = Field(..., description="User's display name")
    created_at: date = Field(default_factory=date.today, description="Date when the user was created")
    prompt: Optional[str] = Field(None, description="Generated prompt for the user's agent")
    # Add other fields as needed (e.g., profile picture URL, preferences, etc.)

    class Config:
        from_attributes = True

class UserResponse(UserBase):
    user_id: str
    email: EmailStr
    prompt: Optional[str] = None

class UserUpdate(BaseModel):
    name: Optional[str] = None
    sex: Optional[str] = None
    birth_date: Optional[date] = None
    mbti: Optional[str] = None
    company: Optional[str] = None
    division: Optional[str] = None
    department: Optional[str] = None
    section: Optional[str] = None
    role: Optional[str] = None
    # Email and password are not updatable via this model by user.
    # Prompt is updated server-side based on other fields.

class Token(BaseModel):
    access_token: str
    token_type: str

class IdTokenRequest(BaseModel):
    id_token: str

class Agent(BaseModel):
    agent_id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    name: str
    description: Optional[str] = None
    default_prompt: str

class ChatGroupCreate(BaseModel):
    group_name: str
    agent_ids: List[str]

from datetime import datetime # Add this import

class ChatGroup(ChatGroupCreate):
    group_id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    created_by: str # user_id
    created_at: datetime = Field(default_factory=datetime.utcnow)
    member_user_ids: List[str] = []
    active_mission_id: Optional[str] = None
    last_message_at: Optional[datetime] = None
    last_message_snippet: Optional[str] = None
    # messages will be a sub-collection in Firestore

class Message(BaseModel):
    message_id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    group_id: str
    sender_id: str # Can be user_id or agent_id
    sender_name: Optional[str] = None # Optional: To display name in chat UI easily
    content: str
    timestamp: datetime = Field(default_factory=datetime.utcnow)

class MissionCreate(BaseModel):
    mission_text: str

class Mission(MissionCreate):
    mission_id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    group_id: str
    status: str = "pending" # e.g., "pending", "in_progress", "completed"
    created_at: datetime = Field(default_factory=datetime.utcnow)
    # updated_at: Optional[datetime] = None # Optional for tracking updates

class Insight(BaseModel):
    insight_id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    group_id: str
    insight_text: str
    generated_at: str # ISO format string
