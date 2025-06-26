from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Depends, HTTPException, status
from firebase_admin import firestore, auth # For auth exceptions, db client

from ..services.chat_service import ChatService
from ..services.auth_service import AuthService # For token verification
from ..services.chat_group_service import ChatGroupService # Added import
from ..utils.firebase_setup import initialize_firebase_admin
from ..models import User # For type hinting if needed

router = APIRouter(
    prefix="/ws", # WebSocket specific prefix
    tags=["Chat WebSocket"],
)

# Initialize Firebase and Firestore client (should be done at startup, but ensure access)
# initialize_firebase_admin() # Done at main app startup
# db = firestore.client() # Get client instance

# Global ChatService instance (or manage via FastAPI dependencies if preferred for complex setup)
# For simplicity, a global instance is often okay for a single chat service.
# Ensure db client is passed if ChatService requires it in constructor.
chat_service_instance = None # Will be initialized after Firebase

def get_chat_service():
    global chat_service_instance
    if chat_service_instance is None:
        initialize_firebase_admin() # Ensure it's called before getting db client
        db_client = firestore.client()
        chat_service_instance = ChatService(db_client=db_client)
    return chat_service_instance


@router.websocket("/chat/{group_id}/{token}")
async def websocket_chat_endpoint(
    websocket: WebSocket,
    group_id: str,
    token: str, # Firebase ID Token passed as path parameter
    chat_service: ChatService = Depends(get_chat_service) # Inject ChatService
):
    """
    WebSocket endpoint for real-time chat in a group.
    - Token: Firebase ID token for authentication.
    - group_id: The ID of the chat group to connect to.
    """
    user_id: str
    user_email: str # Optional, for logging

    try:
        # 1. Authenticate the user via the token
        decoded_token = await AuthService.verify_firebase_id_token(token)
        user_id = decoded_token.get("uid")
        user_email = decoded_token.get("email", "N/A") # For logging
        if not user_id:
            await websocket.close(code=status.WS_1008_POLICY_VIOLATION, reason="Invalid token: UID missing.")
            return

        # (Optional but Recommended) Further check if user is a member of group_id
        # initialize_firebase_admin() # Ensure it's initialized globally
        # db_temp = firestore.client()
        # group_info = await ChatGroupService.get_chat_group_by_id(group_id, db_temp)
        # if not group_info or (user_id not in group_info.member_user_ids and user_id != group_info.created_by):
        #     await websocket.close(code=status.WS_1008_POLICY_VIOLATION, reason="User not authorized for this group.")
        #     return
        # For now, basic token auth is assumed sufficient for connection. Access control is on HTTP routes.

    except HTTPException as e: # Catch HTTPException from verify_firebase_id_token
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION, reason=f"Authentication failed: {e.detail}")
        return
    except Exception as e:
        await websocket.close(code=status.WS_1011_INTERNAL_ERROR, reason=f"Authentication error: {str(e)}")
        return

    # 2. Connect to the ConnectionManager
    await chat_service.manager.connect(group_id, websocket)
    print(f"User {user_id} ({user_email}) connected via WebSocket to group {group_id}")

    try:
        # 3. Listen for messages from the client
        while True:
            data = await websocket.receive_text()
            # Process the received text data (e.g., a raw message string)
            # The ChatService will handle storing it, broadcasting, and triggering agent responses.
            await chat_service.handle_websocket_message(group_id, user_id, data)

    except WebSocketDisconnect as e:
        chat_service.manager.disconnect(group_id, websocket)
        print(f"User {user_id} ({user_email}) disconnected via WebSocket from group {group_id}. Code: {e.code}, Reason: {e.reason or 'N/A'}")
    except Exception as e:
        # Handle other exceptions that might occur during the WebSocket lifetime
        print(f"Unexpected error for user {user_id} in group {group_id} WebSocket: {e}")
        chat_service.manager.disconnect(group_id, websocket) # Ensure cleanup
        # Attempt to close gracefully if not already closed by WebSocketDisconnect
        try:
            await websocket.close(code=status.WS_1011_INTERNAL_ERROR, reason="Server error")
        except Exception:
            # Websocket might already be closed
            pass
```
