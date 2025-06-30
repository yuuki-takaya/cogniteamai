from fastapi import APIRouter, Depends, HTTPException, status, Request, Response
from fastapi.responses import StreamingResponse
from firebase_admin import firestore, auth
import asyncio
import json
from typing import Dict, Set
from datetime import datetime

from services.chat_service import ChatService, ConnectionManager
from services.auth_service import AuthService
from services.chat_group_service import ChatGroupService
from utils.firebase_setup import initialize_firebase_admin
from models import Message

router = APIRouter(
    prefix="/sse",
    tags=["Server-Sent Events"],
)

# Global ChatService instance
chat_service_instance = None

def get_chat_service():
    global chat_service_instance
    if chat_service_instance is None:
        initialize_firebase_admin()
        db_client = firestore.client()
        chat_service_instance = ChatService(db_client=db_client)
    return chat_service_instance

# Store active SSE connections
active_sse_connections: Dict[str, Set[asyncio.Queue]] = {}

# Store active simulation SSE connections (user-based)
active_simulation_sse_connections: Dict[str, Set[asyncio.Queue]] = {}

async def sse_generator(group_id: str, user_id: str, queue: asyncio.Queue):
    """Generate SSE events from the queue"""
    try:
        while True:
            # Wait for messages from the queue with longer timeout
            message = await asyncio.wait_for(queue.get(), timeout=60.0)
            if message is None:  # Shutdown signal
                break
            
            # Format as SSE event
            yield f"data: {json.dumps(message)}\n\n"
    except asyncio.TimeoutError:
        # Send keepalive
        yield ": keepalive\n\n"
    except Exception as e:
        print(f"SSE generator error for user {user_id} in group {group_id}: {e}")
    finally:
        # Cleanup
        if group_id in active_sse_connections:
            active_sse_connections[group_id].discard(queue)
            print(f"SSE: Removed connection from group {group_id}. Remaining connections: {len(active_sse_connections[group_id])}")
            if not active_sse_connections[group_id]:
                del active_sse_connections[group_id]
                print(f"SSE: No more connections for group {group_id}, removed from active connections")

async def simulation_sse_generator(user_id: str, queue: asyncio.Queue):
    """Generate SSE events for simulation notifications"""
    try:
        while True:
            # Wait for messages from the queue with longer timeout
            message = await asyncio.wait_for(queue.get(), timeout=60.0)
            if message is None:  # Shutdown signal
                break
            
            # Format as SSE event
            yield f"data: {json.dumps(message)}\n\n"
    except asyncio.TimeoutError:
        # Send keepalive
        yield ": keepalive\n\n"
    except Exception as e:
        print(f"Simulation SSE generator error for user {user_id}: {e}")
    finally:
        # Cleanup
        if user_id in active_simulation_sse_connections:
            active_simulation_sse_connections[user_id].discard(queue)
            print(f"Simulation SSE: Removed connection for user {user_id}. Remaining connections: {len(active_simulation_sse_connections[user_id])}")
            if not active_simulation_sse_connections[user_id]:
                del active_simulation_sse_connections[user_id]
                print(f"Simulation SSE: No more connections for user {user_id}, removed from active connections")

async def broadcast_to_sse_group(group_id: str, message_data: dict):
    """Broadcast message to all SSE connections in a group"""
    print(f"SSE: Broadcasting to group {group_id}: {message_data}")
    if group_id in active_sse_connections:
        print(f"SSE: Found {len(active_sse_connections[group_id])} active SSE connections")
        for queue in active_sse_connections[group_id]:
            try:
                await queue.put(message_data)
                print(f"SSE: Message sent to SSE queue successfully")
            except Exception as e:
                print(f"Error broadcasting to SSE connection in group {group_id}: {e}")
    else:
        print(f"SSE: No active SSE connections found for group {group_id}")

async def broadcast_simulation_notification(user_id: str, notification_data: dict):
    """Broadcast simulation notification to a specific user"""
    print(f"Simulation SSE: Broadcasting to user {user_id}: {notification_data}")
    if user_id in active_simulation_sse_connections:
        print(f"Simulation SSE: Found {len(active_simulation_sse_connections[user_id])} active SSE connections")
        for queue in active_simulation_sse_connections[user_id]:
            try:
                await queue.put(notification_data)
                print(f"Simulation SSE: Notification sent to SSE queue successfully")
            except Exception as e:
                print(f"Error broadcasting simulation notification to user {user_id}: {e}")
    else:
        print(f"Simulation SSE: No active SSE connections found for user {user_id}")

@router.get("/chat/{group_id}")
async def sse_chat_endpoint(
    request: Request,
    group_id: str,
    chat_service: ChatService = Depends(get_chat_service)
):
    """
    SSE endpoint for real-time chat in a group.
    - Authorization: Bearer token in Authorization header
    - group_id: The ID of the chat group to connect to.
    """
    # Extract token from Authorization header
    auth_header = request.headers.get("Authorization")
    if not auth_header or not auth_header.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing or invalid Authorization header"
        )
    
    token = auth_header.split(" ")[1]
    user_id: str
    user_email: str

    try:
        # Authenticate the user via the token
        decoded_token = await AuthService.verify_firebase_id_token(token)
        user_id = decoded_token.get("uid")
        user_email = decoded_token.get("email", "N/A")
        if not user_id:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token: UID missing"
            )

        # Optional: Check if user is a member of group_id
        # initialize_firebase_admin()
        # db_temp = firestore.client()
        # group_info = await ChatGroupService.get_chat_group_by_id(group_id, db_temp)
        # if not group_info or (user_id not in group_info.member_user_ids and user_id != group_info.created_by):
        #     raise HTTPException(
        #         status_code=status.HTTP_403_FORBIDDEN,
        #         detail="User not authorized for this group"
        #     )

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Authentication error: {str(e)}"
        )

    # Create queue for this connection
    queue = asyncio.Queue()
    
    # Add to active connections
    if group_id not in active_sse_connections:
        active_sse_connections[group_id] = set()
    active_sse_connections[group_id].add(queue)
    
    print(f"User {user_id} ({user_email}) connected via SSE to group {group_id}")
    print(f"SSE: Total active connections for group {group_id}: {len(active_sse_connections[group_id])}")

    # Create SSE response
    return StreamingResponse(
        sse_generator(group_id, user_id, queue),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Headers": "Cache-Control, Authorization, Content-Type",
            "Access-Control-Allow-Methods": "GET, OPTIONS",
            "Access-Control-Allow-Private-Network": "true",
            "Access-Control-Allow-Credentials": "true",
        }
    )

@router.get("/simulation")
async def sse_simulation_endpoint(
    request: Request,
):
    """
    SSE endpoint for simulation notifications.
    - Authorization: Bearer token in Authorization header
    - User-specific notifications for simulation completion
    """
    # Extract token from Authorization header
    auth_header = request.headers.get("Authorization")
    if not auth_header or not auth_header.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing or invalid Authorization header"
        )
    
    token = auth_header.split(" ")[1]
    user_id: str
    user_email: str

    try:
        # Authenticate the user via the token
        decoded_token = await AuthService.verify_firebase_id_token(token)
        user_id = decoded_token.get("uid")
        user_email = decoded_token.get("email", "N/A")
        if not user_id:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token: UID missing"
            )

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Authentication error: {str(e)}"
        )

    # Create queue for this connection
    queue = asyncio.Queue()
    
    # Add to active simulation connections
    if user_id not in active_simulation_sse_connections:
        active_simulation_sse_connections[user_id] = set()
    active_simulation_sse_connections[user_id].add(queue)
    
    print(f"User {user_id} ({user_email}) connected via SSE for simulation notifications")
    print(f"Simulation SSE: Total active connections for user {user_id}: {len(active_simulation_sse_connections[user_id])}")

    # Create SSE response with CORS headers
    return StreamingResponse(
        simulation_sse_generator(user_id, queue),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Headers": "Cache-Control, Authorization, Content-Type",
            "Access-Control-Allow-Methods": "GET, OPTIONS",
            "Access-Control-Allow-Private-Network": "true",
            "Access-Control-Allow-Credentials": "true",
        }
    )

@router.options("/simulation")
async def sse_simulation_options():
    """
    Handle OPTIONS request for SSE simulation endpoint
    """
    return Response(
        status_code=200,
        headers={
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Headers": "Cache-Control, Authorization, Content-Type",
            "Access-Control-Allow-Methods": "GET, OPTIONS",
            "Access-Control-Allow-Private-Network": "true",
            "Access-Control-Allow-Credentials": "true",
        }
    )

@router.options("/chat/{group_id}")
async def sse_chat_options():
    """
    Handle OPTIONS request for SSE chat endpoint
    """
    return Response(
        status_code=200,
        headers={
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Headers": "Cache-Control, Authorization, Content-Type",
            "Access-Control-Allow-Methods": "GET, OPTIONS",
            "Access-Control-Allow-Private-Network": "true",
            "Access-Control-Allow-Credentials": "true",
        }
    )

# Modify ChatService to also broadcast to SSE connections
def setup_sse_broadcasting():
    """Setup SSE broadcasting in ChatService"""
    # Store the original broadcast method from ConnectionManager
    original_broadcast = ConnectionManager.broadcast_to_group
    
    async def broadcast_to_all(self, group_id: str, message_json: str):
        # Original WebSocket broadcast
        await original_broadcast(self, group_id, message_json)
        
        # SSE broadcast
        try:
            message_data = json.loads(message_json)
            await broadcast_to_sse_group(group_id, message_data)
        except Exception as e:
            print(f"Error broadcasting to SSE: {e}")
    
    # Replace the ConnectionManager's broadcast method
    ConnectionManager.broadcast_to_group = broadcast_to_all

# Initialize SSE broadcasting
setup_sse_broadcasting() 