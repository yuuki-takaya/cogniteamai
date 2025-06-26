from fastapi import WebSocket, WebSocketDisconnect
from typing import Dict, List, Set, Optional
# from firebase_admin import firestore # Potentially not needed directly if db_client is removed
from google.cloud import aiplatform

from ..config import settings
from .chat_group_service import ChatGroupService
from .agent_service import AgentService
from .user_service import UserService
from ..models import Message as MessageModel, Agent as AgentModel, Mission as MissionModel
import json

class ConnectionManager:
    def __init__(self):
        self.active_connections: Dict[str, Set[WebSocket]] = {}

    async def connect(self, group_id: str, websocket: WebSocket):
        await websocket.accept()
        if group_id not in self.active_connections:
            self.active_connections[group_id] = set()
        self.active_connections[group_id].add(websocket)
        print(f"WebSocket connected to group {group_id}. Total: {len(self.active_connections[group_id])}")

    def disconnect(self, group_id: str, websocket: WebSocket):
        if group_id in self.active_connections:
            if websocket in self.active_connections[group_id]:
                 self.active_connections[group_id].remove(websocket)
            if not self.active_connections[group_id]:
                del self.active_connections[group_id]
            print(f"WebSocket disconnected from group {group_id}.")

    async def broadcast_to_group(self, group_id: str, message_json: str):
        if group_id in self.active_connections:
            current_connections_in_group = list(self.active_connections[group_id])
            disconnected_sockets = set()
            for connection in current_connections_in_group:
                try:
                    await connection.send_text(message_json)
                except Exception as e:
                    print(f"Error sending to a WebSocket in group {group_id}: {e}. Marking for removal.")
                    disconnected_sockets.add(connection)

            if disconnected_sockets:
                for sock_to_remove in disconnected_sockets:
                    if group_id in self.active_connections and sock_to_remove in self.active_connections[group_id]:
                        self.active_connections[group_id].remove(sock_to_remove)
                if group_id in self.active_connections and not self.active_connections[group_id]:
                    del self.active_connections[group_id]

class ChatService:
    _vertex_ai_initialized = False

    def __init__(self,
                 # db_client: firestore.client, # Removed
                 chat_group_service: ChatGroupService,
                 user_service: UserService,
                 agent_service: AgentService):
        # self.db = db_client # No longer storing db_client directly
        self.chat_group_service = chat_group_service
        self.user_service = user_service
        self.agent_service = agent_service
        self.manager = ConnectionManager()
        self.vertex_ai_enabled = False

        if not ChatService._vertex_ai_initialized:
            try:
                aiplatform.init(project=settings.VERTEX_AI_PROJECT, location=settings.VERTEX_AI_LOCATION)
                print(f"Vertex AI initialized for ChatService: {settings.VERTEX_AI_PROJECT} in {settings.VERTEX_AI_LOCATION}")
                ChatService._vertex_ai_initialized = True
                self.vertex_ai_enabled = True
            except Exception as e:
                if "already initialized" in str(e).lower() or \
                   (hasattr(aiplatform.initializer, 'global_config') and aiplatform.initializer.global_config.project):
                    print(f"Vertex AI was already initialized (ChatService). Project: {aiplatform.initializer.global_config.project if hasattr(aiplatform.initializer, 'global_config') else 'Unknown'}")
                    ChatService._vertex_ai_initialized = True
                    self.vertex_ai_enabled = True
                else:
                    print(f"Failed to initialize Vertex AI in ChatService: {e}. Agent responses may be limited.")
                    self.vertex_ai_enabled = False
        else:
            self.vertex_ai_enabled = True if (hasattr(aiplatform.initializer, 'global_config') and aiplatform.initializer.global_config.project) else False
            if self.vertex_ai_enabled:
                print(f"Vertex AI already initialized, confirmed for ChatService. Project: {aiplatform.initializer.global_config.project if hasattr(aiplatform.initializer, 'global_config') else 'Unknown'}")

    async def handle_websocket_message(self, group_id: str, user_id: str, data: str):
        user_profile_dict = await self.user_service.get_user_by_id(user_id)
        user_name = user_profile_dict.get('name', "Unknown User") if user_profile_dict else "Unknown User"

        print(f"Message from user {user_id} ({user_name}) in group {group_id}: {data}")

        stored_message = await self.chat_group_service.add_message_to_group(
            group_id=group_id,
            sender_id=user_id,
            sender_name=user_name,
            content=data
            # db_client is handled by chat_group_service instance
        )

        if not stored_message:
            print(f"Error: Failed to store user message from {user_id} in group {group_id}.")
            return

        await self.manager.broadcast_to_group(group_id, stored_message.model_dump_json())

        if self.vertex_ai_enabled:
            await self.trigger_agent_responses_for_group(group_id, stored_message)
        else:
            print("Vertex AI is not enabled. Skipping agent responses.")

    async def trigger_agent_responses_for_group(self, group_id: str, last_human_message: MessageModel):
        group_info = await self.chat_group_service.get_chat_group_by_id(group_id)
        if not group_info or not group_info.agent_ids:
            print(f"No agents configured for group {group_id} or group not found.")
            return

        active_mission: Optional[MissionModel] = None
        if group_info.active_mission_id:
            active_mission = await self.chat_group_service.get_active_mission_for_group(group_id)

        for agent_id in group_info.agent_ids:
            agent_profile = await self.agent_service.get_agent_by_id(agent_id)
            if not agent_profile:
                print(f"Agent profile for {agent_id} not found. Skipping response.")
                continue

            recent_messages_models = await self.chat_group_service.get_messages_for_group(group_id, limit=10)

            history_for_prompt = []
            for msg_model in recent_messages_models:
                history_for_prompt.append({
                    "sender_id": msg_model.sender_id,
                    "sender_name": msg_model.sender_name or msg_model.sender_id,
                    "content": msg_model.content
                })

            vertex_prompt = self._build_vertex_prompt(
                agent_profile=agent_profile,
                mission=active_mission,
                conversation_history=history_for_prompt,
                last_message_from_human=last_human_message
            )

            print(f"Invoking Vertex AI for agent {agent_id} ({agent_profile.name}) in group {group_id}...")
            agent_reply_content = ""
            try:
                # --- Vertex AI Call Placeholder ---
                if "hello" in last_human_message.content.lower() and "Friendly Assistant" in agent_profile.name:
                    agent_reply_content = f"Hello from {agent_profile.name}! How can I help you today?"
                elif "mission" in last_human_message.content.lower() and active_mission:
                     agent_reply_content = f"{agent_profile.name} here. I'm ready for the mission: {active_mission.mission_text}"
                elif "mission" in last_human_message.content.lower() and not active_mission:
                     agent_reply_content = f"{agent_profile.name} here. There is no active mission!"
                else:
                    agent_reply_content = f"This is a placeholder response from {agent_profile.name} regarding '{last_human_message.content[:30]}...'. Full Vertex AI integration is pending."
                # --- End of Vertex AI Call Placeholder ---

                if agent_reply_content:
                    print(f"Agent {agent_id} ({agent_profile.name}) generated reply: {agent_reply_content}")
                    stored_agent_message = await self.chat_group_service.add_message_to_group(
                        group_id=group_id,
                        sender_id=agent_id,
                        sender_name=agent_profile.name,
                        content=agent_reply_content
                    )
                    if stored_agent_message:
                        await self.manager.broadcast_to_group(group_id, stored_agent_message.model_dump_json())
                    else:
                        print(f"Error: Failed to store agent message from {agent_id} in group {group_id}.")
                else:
                    print(f"Agent {agent_id} ({agent_profile.name}) did not generate a reply for this turn.")
            except Exception as e:
                print(f"Error during Vertex AI call or processing for agent {agent_id}: {e}")
                error_msg_model = MessageModel(
                    group_id=group_id, sender_id="system", sender_name="System",
                    content=f"Error with agent {agent_profile.name}: Could not generate response."
                )
                await self.manager.broadcast_to_group(group_id, error_msg_model.model_dump_json())

    def _build_vertex_prompt(
        self,
        agent_profile: AgentModel,
        mission: Optional[MissionModel],
        conversation_history: List[Dict[str,str]],
        last_message_from_human: MessageModel
    ) -> str:
        prompt_lines = [agent_profile.default_prompt]
        if mission:
            prompt_lines.append(f"\nCurrent Mission: {mission.mission_text} (Status: {mission.status})")
        else:
            prompt_lines.append("\nCurrent Mission: None assigned.")

        prompt_lines.append("\nConversation History (most recent message is last):")
        if not conversation_history:
            prompt_lines.append("- (No prior messages in this context window)")
        else:
            for msg in conversation_history:
                if msg["sender_id"] == agent_profile.agent_id:
                    sender_display = f"You ({agent_profile.name})"
                else:
                    sender_display = msg["sender_name"]
                prompt_lines.append(f"- {sender_display}: {msg['content']}")

        prompt_lines.append(f"\nConsidering the information above, your name is {agent_profile.name}. Please provide your response as this agent.")
        prompt_lines.append("Focus on the most recent messages and the overall mission if applicable.")
        prompt_lines.append(f"Respond to the last message from {last_human_message.sender_name or last_human_message.sender_id}: \"{last_human_message.content}\"")

        return "\n".join(prompt_lines)

```
