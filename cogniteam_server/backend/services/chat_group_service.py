from firebase_admin import firestore
from typing import Optional # Added for Optional type hint
from models import ChatGroup, ChatGroupCreate, Message, Mission # Pydantic models
from services.user_service import UserService # Potentially to validate user
from services.agent_service import AgentService # Potentially to validate agents
import uuid
from datetime import datetime, timezone
from utils.firebase_setup import initialize_firebase_admin

class ChatGroupService:

    @staticmethod
    async def create_chat_group(
        group_data: ChatGroupCreate,
        creator_user_id: str,
        db_client
    ) -> ChatGroup | None:
        """
        Creates a new chat group document in Firestore.
        - group_data: Contains group_name and agent_ids.
        - creator_user_id: The ID of the user creating the group.
        - db_client: Firestore client instance.
        Returns a ChatGroup Pydantic model instance if successful, None otherwise.
        """
        chat_groups_collection = db_client.collection('chat_groups')
        group_id = str(uuid.uuid4()) # Generate a unique ID for the chat group

        try:
            # Optional: Validate that all agent_ids in group_data.agent_ids exist.
            # This adds overhead but ensures data integrity.
            # for agent_id in group_data.agent_ids:
            #     agent = await AgentService.get_agent_by_id(agent_id, db_client)
            #     if not agent:
            #         print(f"Validation Error: Agent with ID {agent_id} not found during chat group creation.")
            #         # Depending on strictness, could raise an error or just log and proceed.
            #         # For now, let's assume agent IDs are validated client-side or are trusted.
            #         pass


            new_group_dict = {
                "group_id": group_id,
                "group_name": group_data.group_name,
                "agent_ids": group_data.agent_ids, # List of agent UIDs
                "created_by": creator_user_id,   # UID of the user who created the group
                "created_at": datetime.now(timezone.utc).isoformat(),
                "member_user_ids": [creator_user_id], # Initially, only creator is a member. Can be expanded.
                "active_mission_id": None, # No active mission when group is created
                "last_message_at": None, # For sorting/filtering groups by activity
                "last_message_snippet": None, # For display purposes
            }

            chat_groups_collection.document(group_id).set(new_group_dict)
            print(f"Successfully created chat group '{group_data.group_name}' with ID: {group_id} by user {creator_user_id}")

            return ChatGroup(**new_group_dict)

        except Exception as e:
            print(f"Error creating chat group '{group_data.group_name}': {e}")
            return None

    @staticmethod
    async def get_chat_group_by_id(group_id: str, db_client) -> ChatGroup | None:
        """
        Fetches a chat group by its ID.
        """
        chat_groups_collection = db_client.collection('chat_groups')
        try:
            doc_ref = chat_groups_collection.document(group_id)
            doc = doc_ref.get()
            if doc.exists:
                return ChatGroup(**doc.to_dict())
            return None
        except Exception as e:
            print(f"Error fetching chat group {group_id}: {e}")
            return None

    @staticmethod
    async def add_message_to_group(group_id: str, sender_id: str, content: str, db_client, sender_name: Optional[str] = None) -> Message | None:
        """
        Adds a message to a specific chat group's 'messages' subcollection.
        Updates the group's last_message_at and last_message_snippet.
        sender_name is optional; if not provided, it might be fetched or left null.
        """
        chat_groups_collection = db_client.collection('chat_groups')
        group_doc_ref = chat_groups_collection.document(group_id)
        messages_subcollection = group_doc_ref.collection('messages')

        message_id = str(uuid.uuid4())
        timestamp_now = datetime.now(timezone.utc) # Pydantic model will use this as default if not passed

        # Attempt to determine sender_name if not provided
        if sender_name is None:
            # Check if sender_id is a known user
            user = await UserService.get_user_by_id(sender_id, db_client)
            if user:
                sender_name = user.get('name', 'Unknown User')
            else:
                # Check if sender_id is a known agent
                agent = await AgentService.get_agent_by_id(sender_id, db_client)
                if agent:
                    sender_name = agent.name
                else:
                    sender_name = "Unknown Sender"

        try:
            message_data = Message(
                message_id=message_id,
                group_id=group_id,
                sender_id=sender_id,
                sender_name=sender_name,
                content=content,
                timestamp=timestamp_now # Pass datetime object
            )

            # Pydantic .model_dump() will serialize datetime to ISO string
            messages_subcollection.document(message_id).set(message_data.model_dump())

            # Update the parent group document with last message info
            group_doc_ref.update({
                "last_message_at": timestamp_now, # Store datetime object, Firestore handles serialization
                "last_message_snippet": content[:100] # Store a snippet
            })

            print(f"Message added to group {group_id} by {sender_id}")
            return message_data

        except Exception as e:
            print(f"Error adding message to group {group_id}: {e}")
            return None

    @staticmethod
    async def get_messages_for_group(group_id: str, db_client, limit: int = 50) -> list[Message]:
        """
        Retrieves messages for a chat group, ordered by timestamp.
        """
        chat_groups_collection = db_client.collection('chat_groups')
        messages_subcollection = chat_groups_collection.document(group_id).collection('messages')

        messages_list = []
        try:
            # Order by timestamp, descending to get the latest, then limit.
            # Client-side can reverse if needed for display.
            query = messages_subcollection.order_by('timestamp', direction=firestore.Query.DESCENDING).limit(limit)
            docs_stream = query.stream()

            for doc in docs_stream:
                messages_list.append(Message(**doc.to_dict()))

            # Messages are currently latest first, reverse to get chronological for typical display
            return sorted(messages_list, key=lambda m: m.timestamp)

        except Exception as e:
            print(f"Error fetching messages for group {group_id}: {e}")
            return []

    # Placeholder for setting/updating mission, getting user's groups, etc.
    # async def get_chat_groups_for_user(...)

    @staticmethod
    async def set_or_update_mission(group_id: str, mission_text: str, db_client) -> Mission | None:
        """
        Sets or updates the active mission for a chat group.
        If a mission already exists, it might be updated, or a new one created
        and the group's active_mission_id updated.
        For simplicity, this creates a new mission and updates active_mission_id.
        Older missions could be kept for history if their status is changed (e.g., to 'archived').
        """
        chat_groups_collection = db_client.collection('chat_groups')
        group_doc_ref = chat_groups_collection.document(group_id)

        # Check if group exists
        group_doc = group_doc_ref.get()
        if not group_doc.exists:
            print(f"Group {group_id} not found. Cannot set mission.")
            return None

        mission_id = str(uuid.uuid4())
        new_mission_data = Mission(
            mission_id=mission_id,
            group_id=group_id,
            mission_text=mission_text,
            status="active", # New missions are active by default
            created_at=datetime.now(timezone.utc) # Pydantic default, but can be explicit
        )

        try:
            # Store the mission in a subcollection 'missions' under the group document
            missions_subcollection = group_doc_ref.collection('missions')
            missions_subcollection.document(mission_id).set(new_mission_data.model_dump())

            # Update the group document to point to this new active mission
            group_doc_ref.update({"active_mission_id": mission_id})

            print(f"Mission {mission_id} set for group {group_id}: {mission_text}")
            return new_mission_data
        except Exception as e:
            print(f"Error setting mission for group {group_id}: {e}")
            return None

    @staticmethod
    async def get_active_mission_for_group(group_id: str, db_client) -> Mission | None:
        """
        Retrieves the currently active mission for a group, if one is set.
        """
        group_doc = await ChatGroupService.get_chat_group_by_id(group_id, db_client)
        if not group_doc or not group_doc.active_mission_id:
            return None

        try:
            mission_doc_ref = db_client.collection('chat_groups').document(group_id).collection('missions').document(group_doc.active_mission_id)
            mission_doc = mission_doc_ref.get()
            if mission_doc.exists:
                return Mission(**mission_doc.to_dict())
            return None
        except Exception as e:
            print(f"Error fetching active mission {group_doc.active_mission_id} for group {group_id}: {e}")
            return None
