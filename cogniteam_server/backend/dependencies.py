from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from firebase_admin import firestore

from .services.auth_service import AuthService
from .services.user_service import UserService
from .services.agent_service import AgentService
from .services.chat_group_service import ChatGroupService
from .services.insight_service import InsightService
from .services.chat_service import ChatService # Import ChatService
from .models import User
from .utils.firebase_setup import initialize_firebase_admin

# --- Helper to get Firestore client ---
_db_client_instance = None

def get_db_client() -> firestore.client:
    global _db_client_instance
    if _db_client_instance is None:
        initialize_firebase_admin()
        _db_client_instance = firestore.client()
    return _db_client_instance

# --- Service Dependencies ---
_user_service_singleton = None
def get_user_service(db: firestore.client = Depends(get_db_client)) -> UserService:
    global _user_service_singleton
    if _user_service_singleton is None:
        _user_service_singleton = UserService(db_client=db)
    return _user_service_singleton

_auth_service_singleton = None
def get_auth_service(db: firestore.client = Depends(get_db_client)) -> AuthService:
    global _auth_service_singleton
    if _auth_service_singleton is None:
        _auth_service_singleton = AuthService(db_client=db)
    return _auth_service_singleton

_agent_service_singleton = None
def get_agent_service(db: firestore.client = Depends(get_db_client)) -> AgentService:
    global _agent_service_singleton
    if _agent_service_singleton is None:
        _agent_service_singleton = AgentService(db_client=db)
    return _agent_service_singleton

_chat_group_service_singleton = None
def get_chat_group_service(
    db: firestore.client = Depends(get_db_client),
    user_service: UserService = Depends(get_user_service),
    agent_service: AgentService = Depends(get_agent_service)
) -> ChatGroupService:
    global _chat_group_service_singleton
    if _chat_group_service_singleton is None:
        _chat_group_service_singleton = ChatGroupService(
            db_client=db,
            user_service=user_service,
            agent_service=agent_service
        )
    return _chat_group_service_singleton

_insight_service_singleton = None
def get_insight_service(
    db: firestore.client = Depends(get_db_client), # db might be unused if InsightService changes
    chat_group_service: ChatGroupService = Depends(get_chat_group_service)
) -> InsightService:
    global _insight_service_singleton
    if _insight_service_singleton is None:
        _insight_service_singleton = InsightService(
            db_client=db, # Pass db if InsightService constructor still needs it
            chat_group_service=chat_group_service
        )
    return _insight_service_singleton

_chat_service_singleton = None
def get_chat_service(
    # db: firestore.client = Depends(get_db_client), # ChatService no longer takes db_client directly
    chat_group_service: ChatGroupService = Depends(get_chat_group_service),
    user_service: UserService = Depends(get_user_service),
    agent_service: AgentService = Depends(get_agent_service)
) -> ChatService:
    """Dependency to get a ChatService instance."""
    global _chat_service_singleton
    if _chat_service_singleton is None:
        _chat_service_singleton = ChatService(
            # db_client=db, # Removed
            chat_group_service=chat_group_service,
            user_service=user_service,
            agent_service=agent_service
        )
    return _chat_service_singleton

# --- Authentication Dependencies ---
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login")

async def get_current_user(
    token: str = Depends(oauth2_scheme),
    user_service: UserService = Depends(get_user_service)
) -> User:
    try:
        decoded_token = await AuthService.verify_firebase_id_token(token)
        uid = decoded_token.get("uid")
        if not uid:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid ID token: UID not found after verification.",
                headers={"WWW-Authenticate": "Bearer"},
            )
        user_data_dict = await user_service.get_user_by_id(uid)
        if not user_data_dict:
            email = decoded_token.get("email", "N/A")
            print(f"User with UID {uid} (Email: {email}) authenticated via Firebase, but profile not found in Firestore.")
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"User profile not found for authenticated user (UID: {uid}).",
                headers={"WWW-Authenticate": "Bearer"},
            )
        return User(**user_data_dict)
    except HTTPException as e:
        raise e
    except Exception as e:
        print(f"Unexpected error in get_current_user dependency: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An unexpected error occurred while authenticating: {str(e)}",
            headers={"WWW-Authenticate": "Bearer"},
        )

async def get_current_active_user(current_user: User = Depends(get_current_user)) -> User:
    return current_user
```
