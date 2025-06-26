from firebase_admin import firestore
from typing import Optional, List
from ..models import ChatGroup, ChatGroupCreate, Message, Mission, MissionCreate # Pydantic models
from .user_service import UserService
from .agent_service import AgentService
import uuid
from datetime import datetime, timezone
# from ..utils.firebase_setup import initialize_firebase_admin # Not needed directly in methods

class ChatGroupService:

    def __init__(self, db_client: firestore.client, user_service: UserService, agent_service: AgentService):
        self.db = db_client
        self.user_service = user_service
        self.agent_service = agent_service

    async def create_chat_group(
        self,
        group_data: ChatGroupCreate,
        creator_user_id: str
    ) -> ChatGroup | None:
        chat_groups_collection = self.db.collection('chat_groups')
        group_id = str(uuid.uuid4())

        try:
            # Optional: Validate agents using self.agent_service
            for agent_id in group_data.agent_ids:
                agent = await self.agent_service.get_agent_by_id(agent_id) # No db_client needed
                if not agent:
                    print(f"Validation Error: Agent with ID {agent_id} not found during chat group creation.")
                    return None

            new_group_data_dict = {
                "group_id": group_id,
                "group_name": group_data.group_name,
                "agent_ids": group_data.agent_ids,
                "created_by": creator_user_id,
                "created_at": datetime.now(timezone.utc),
                "member_user_ids": [creator_user_id],
                "active_mission_id": None,
                "last_message_at": None,
                "last_message_snippet": None,
            }

            # Use Pydantic model to ensure type correctness before saving
            new_group_obj = ChatGroup(**new_group_data_dict)
            chat_groups_collection.document(group_id).set(new_group_obj.model_dump()) # model_dump handles datetime to str for JSON-like dict

            print(f"Successfully created chat group '{new_group_obj.group_name}' with ID: {group_id} by user {creator_user_id}")
            return new_group_obj

        except Exception as e:
            print(f"Error creating chat group '{group_data.group_name}': {e}")
            return None

    async def get_chat_group_by_id(self, group_id: str) -> ChatGroup | None:
        chat_groups_collection = self.db.collection('chat_groups')
        try:
            doc_ref = chat_groups_collection.document(group_id)
            doc = doc_ref.get()
            if doc.exists:
                data = doc.to_dict()
                # Ensure datetime fields are parsed correctly if stored as strings by older code or model_dump
                if isinstance(data.get("created_at"), str):
                    data["created_at"] = datetime.fromisoformat(data["created_at"])
                if isinstance(data.get("last_message_at"), str):
                     data["last_message_at"] = datetime.fromisoformat(data["last_message_at"])
                return ChatGroup(**data)
            return None
        except Exception as e:
            print(f"Error fetching chat group {group_id}: {e}")
            return None

    async def add_message_to_group(self, group_id: str, sender_id: str, content: str, sender_name: Optional[str] = None) -> Message | None:
        group_doc_ref = self.db.collection('chat_groups').document(group_id)
        messages_subcollection = group_doc_ref.collection('messages')

        message_id = str(uuid.uuid4())
        timestamp_now = datetime.now(timezone.utc)

        if sender_name is None:
            user_data = await self.user_service.get_user_by_id(sender_id)
            if user_data: # user_data is a dict
                sender_name = user_data.get('name', 'Unknown User')
            else:
                agent = await self.agent_service.get_agent_by_id(sender_id)
                if agent: # agent is Agent model
                    sender_name = agent.name
                else:
                    sender_name = "Unknown Sender"

        try:
            message_obj = Message(
                message_id=message_id,
                group_id=group_id,
                sender_id=sender_id,
                sender_name=sender_name,
                content=content,
                timestamp=timestamp_now
            )

            messages_subcollection.document(message_id).set(message_obj.model_dump())

            group_doc_ref.update({
                "last_message_at": timestamp_now,
                "last_message_snippet": content[:100]
            })

            print(f"Message added to group {group_id} by {sender_id}")
            return message_obj

        except Exception as e:
            print(f"Error adding message to group {group_id}: {e}")
            return None

    async def get_messages_for_group(self, group_id: str, limit: int = 50) -> list[Message]:
        messages_subcollection = self.db.collection('chat_groups').document(group_id).collection('messages')
        messages_list = []
        try:
            query = messages_subcollection.order_by('timestamp', direction=firestore.Query.DESCENDING).limit(limit)
            docs_stream = query.stream()

            for doc in docs_stream:
                data = doc.to_dict()
                if isinstance(data.get("timestamp"), str): # Compatibility for string timestamps
                    data["timestamp"] = datetime.fromisoformat(data["timestamp"])
                messages_list.append(Message(**data))

            return sorted(messages_list, key=lambda m: m.timestamp)

        except Exception as e:
            print(f"Error fetching messages for group {group_id}: {e}")
            return []

    async def set_or_update_mission(self, group_id: str, mission_data: MissionCreate) -> Mission | None: # Changed input to MissionCreate
        group_doc_ref = self.db.collection('chat_groups').document(group_id)

        group_doc = group_doc_ref.get()
        if not group_doc.exists:
            print(f"Group {group_id} not found. Cannot set mission.")
            return None

        mission_id = str(uuid.uuid4())
        new_mission_obj = Mission(
            mission_id=mission_id,
            group_id=group_id,
            mission_text=mission_data.mission_text, # From MissionCreate
            status="active",
            created_at=datetime.now(timezone.utc)
        )

        try:
            missions_subcollection = group_doc_ref.collection('missions')
            missions_subcollection.document(mission_id).set(new_mission_obj.model_dump())
            group_doc_ref.update({"active_mission_id": mission_id})

            print(f"Mission {mission_id} set for group {group_id}: {mission_data.mission_text}")
            return new_mission_obj
        except Exception as e:
            print(f"Error setting mission for group {group_id}: {e}")
            return None

    async def get_active_mission_for_group(self, group_id: str) -> Mission | None:
        group_obj = await self.get_chat_group_by_id(group_id)
        if not group_obj or not group_obj.active_mission_id:
            return None

        try:
            mission_doc_ref = self.db.collection('chat_groups').document(group_id).collection('missions').document(group_obj.active_mission_id)
            mission_doc = mission_doc_ref.get()
            if mission_doc.exists:
                data = mission_doc.to_dict()
                if isinstance(data.get("created_at"), str): # Compatibility
                    data["created_at"] = datetime.fromisoformat(data["created_at"])
                return Mission(**data)
            return None
        except Exception as e:
            print(f"Error fetching active mission {group_obj.active_mission_id} for group {group_id}: {e}")
            return None

    async def get_chat_groups_for_user(self, user_id: str) -> List[ChatGroup]:
        chat_groups_collection = self.db.collection('chat_groups')
        user_groups_list = []
        try:
            docs = chat_groups_collection.where(filter=firestore.FieldFilter('member_user_ids', 'array_contains', user_id)).stream()
            for doc in docs:
                data = doc.to_dict()
                if isinstance(data.get("created_at"), str):
                    data["created_at"] = datetime.fromisoformat(data["created_at"])
                if data.get("last_message_at") and isinstance(data.get("last_message_at"), str):
                     data["last_message_at"] = datetime.fromisoformat(data["last_message_at"])
                user_groups_list.append(ChatGroup(**data))
            return user_groups_list
        except Exception as e:
            print(f"Error fetching chat groups for user {user_id}: {e}")
            return []

```
