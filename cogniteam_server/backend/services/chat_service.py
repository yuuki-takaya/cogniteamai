from fastapi import WebSocket, WebSocketDisconnect
from typing import Dict, List, Tuple, Set
from firebase_admin import firestore
from google.cloud import aiplatform # For Vertex AI
from config import settings # For Vertex AI project details
from services.chat_group_service import ChatGroupService
from services.agent_service import AgentService
from services.user_service import UserService # To get user names
from models import Message as MessageModel, Agent as AgentModel, Mission as MissionModel # Pydantic models
from utils.firebase_setup import initialize_firebase_admin
import json # For serializing messages for WebSocket

class ConnectionManager:
    def __init__(self):
        # active_connections: Dict[group_id, Set[WebSocket]]
        self.active_connections: Dict[str, Set[WebSocket]] = {}

    async def connect(self, group_id: str, websocket: WebSocket):
        await websocket.accept()
        if group_id not in self.active_connections:
            self.active_connections[group_id] = set()
        self.active_connections[group_id].add(websocket)
        print(f"WebSocket connected to group {group_id}. Total connections in group: {len(self.active_connections[group_id])}")

    def disconnect(self, group_id: str, websocket: WebSocket):
        if group_id in self.active_connections:
            self.active_connections[group_id].remove(websocket)
            if not self.active_connections[group_id]: # Remove group_id if empty
                del self.active_connections[group_id]
            print(f"WebSocket disconnected from group {group_id}.")
        else:
            print(f"Attempted to disconnect WebSocket from non-tracked group {group_id}.")


    async def broadcast_to_group(self, group_id: str, message_json: str):
        if group_id in self.active_connections:
            # Create a list of tasks for sending messages concurrently
            # tasks = [conn.send_text(message_json) for conn in self.active_connections[group_id]]
            # await asyncio.gather(*tasks) # Requires asyncio import

            # Simpler sequential broadcast for now
            disconnected_sockets = set()
            for connection in self.active_connections[group_id]:
                try:
                    await connection.send_text(message_json)
                except WebSocketDisconnect: # Should not happen here if disconnect is handled by endpoint
                    print(f"WebSocket was already disconnected during broadcast to group {group_id}.")
                    disconnected_sockets.add(connection) # Mark for removal
                except Exception as e: # Other send errors
                    print(f"Error sending message to a WebSocket in group {group_id}: {e}")
                    disconnected_sockets.add(connection) # Mark for removal

            # Clean up sockets that failed during broadcast (if any)
            if disconnected_sockets:
                for sock_to_remove in disconnected_sockets:
                    self.active_connections[group_id].remove(sock_to_remove)
                if not self.active_connections[group_id]:
                    del self.active_connections[group_id]


class ChatService:
    def __init__(self, db_client):
        self.manager = ConnectionManager()
        self.db = db_client # Firestore client instance

        try:
            # Initialize Vertex AI (if not already done globally or per-session)
            # This should ideally use credentials from the environment (GOOGLE_APPLICATION_CREDENTIALS)
            aiplatform.init(
                project=settings.VERTEX_AI_PROJECT,
                location=settings.VERTEX_AI_LOCATION,
            )
            print(f"Vertex AI initialized for project: {settings.VERTEX_AI_PROJECT} in location: {settings.VERTEX_AI_LOCATION}")
        except Exception as e:
            print(f"Failed to initialize Vertex AI: {e}. Agent responses will be disabled.")
            # Potentially set a flag to disable AI features if initialization fails
            self.vertex_ai_enabled = False
        else:
            self.vertex_ai_enabled = True


    async def handle_websocket_message(self, group_id: str, user_id: str, data: str):
        """
        Handles an incoming message from a user via WebSocket.
        1. Stores the user's message in Firestore.
        2. Broadcasts the user's message to all connected clients in the group.
        3. Triggers agent responses if applicable.
        """
        # 1. Store user's message
        user_profile = await UserService.get_user_by_id(user_id, self.db)
        user_name = user_profile.get('name', "Unknown User") if user_profile else "Unknown User"

        print(f"Message from user {user_id} ({user_name}) in group {group_id}: {data}")

        stored_message = await ChatGroupService.add_message_to_group(
            group_id=group_id,
            sender_id=user_id,
            sender_name=user_name,
            content=data,
            db_client=self.db
        )

        if not stored_message:
            print(f"Error: Failed to store user message from {user_id} in group {group_id}.")
            # Optionally send an error message back to the originating user?
            return

        # 2. Broadcast user's message (as Pydantic model serialized to JSON)
        # Ensure the message model sent over WebSocket is consistent (e.g., always MessageModel)
        await self.manager.broadcast_to_group(group_id, stored_message.model_dump_json())

        # 3. Trigger agent responses (Simplified logic for now)
        if self.vertex_ai_enabled:
            await self.trigger_agent_responses_for_group(group_id, stored_message)
        else:
            print("Vertex AI is not enabled. Skipping agent responses.")


    async def trigger_agent_responses_for_group(self, group_id: str, last_human_message: MessageModel):
        """
        Triggers responses from agents in the group based on the last human message.
        """
        group_info = await ChatGroupService.get_chat_group_by_id(group_id, self.db)
        if not group_info or not group_info.agent_ids:
            print(f"No agents configured for group {group_id} or group not found.")
            return

        active_mission = None
        if group_info.active_mission_id:
            active_mission = await ChatGroupService.get_active_mission_for_group(group_id, self.db)

        # For now, let's make each agent respond sequentially.
        # More complex turn-taking or selective response logic can be added later.
        for agent_id in group_info.agent_ids:
            agent_profile = await AgentService.get_agent_by_id(agent_id, self.db)
            if not agent_profile:
                print(f"Agent profile for {agent_id} not found. Skipping response.")
                continue

            # Construct prompt for Vertex AI
            # This needs the conversation history.
            # Fetch recent messages for context.
            recent_messages_models = await ChatGroupService.get_messages_for_group(group_id, self.db, limit=10)

            # Convert Pydantic models to a simpler list of dicts for the prompt helper
            # This history should ideally be formatted for the LLM (e.g., "User: ...", "Agent X: ...")
            history_for_prompt = []
            for msg_model in recent_messages_models:
                history_for_prompt.append({
                    "sender_id": msg_model.sender_id,
                    "sender_name": msg_model.sender_name or msg_model.sender_id, # Fallback to ID if name is null
                    "content": msg_model.content
                })


            vertex_prompt = self._build_vertex_prompt(
                agent_profile=agent_profile,
                mission=active_mission,
                conversation_history=history_for_prompt, # Pass the simplified history
                last_message_from_human=last_human_message # Pass the full model of last human message
            )

            print(f"Invoking Vertex AI for agent {agent_id} ({agent_profile.name}) in group {group_id}...")
            # print(f"Vertex AI Prompt for {agent_profile.name}:\n{vertex_prompt}\n-------------------")

            try:
                # --- Vertex AI Call Placeholder ---
                # The following is a placeholder for actual Vertex AI SDK calls.
                # You would use aiplatform.GenerativeModel for Gemini or similar for other models.
                # Example (conceptual for Gemini):
                #
                # from vertexai.generative_models import GenerativeModel, Part, HarmCategory, HarmBlockThreshold
                # gemini_model = GenerativeModel(settings.VERTEX_AI_CHAT_MODEL_NAME) # e.g., "gemini-1.0-pro"
                # # Construct chat history for Gemini if using its chat capabilities
                # # chat_history_for_gemini = [...]
                # # response = gemini_model.generate_content(
                # #     [vertex_prompt], # Or a more structured input depending on model
                # #     # generation_config=GenerationConfig(...),
                # #     # safety_settings={...},
                # #     # stream=False,
                # # )
                # # agent_reply_content = response.text
                #
                # This part needs to be implemented based on the chosen Vertex AI model and SDK usage.
                # For now, using simplified placeholder logic:

                if "hello" in last_human_message.content.lower() and "Friendly Assistant" in agent_profile.name:
                    agent_reply_content = f"Hello from {agent_profile.name}! How can I help you today?"
                elif "mission" in last_human_message.content.lower():
                     agent_reply_content = f"{agent_profile.name} here. I'm ready for the mission: {active_mission.mission_text if active_mission else 'No mission yet!'}"
                else:
                    agent_reply_content = f"This is a placeholder response from {agent_profile.name} regarding '{last_human_message.content[:30]}...'. Full Vertex AI integration is pending."
                # --- End of Vertex AI Call Placeholder ---

                print(f"Agent {agent_id} ({agent_profile.name}) generated reply: {agent_reply_content}")

                # Store agent's message
                stored_agent_message = await ChatGroupService.add_message_to_group(
                    group_id=group_id,
                    sender_id=agent_id,
                    sender_name=agent_profile.name, # Use agent's actual name
                    content=agent_reply_content,
                    db_client=self.db
                )
                if stored_agent_message:
                    await self.manager.broadcast_to_group(group_id, stored_agent_message.model_dump_json())
                else:
                    print(f"Error: Failed to store agent message from {agent_id} in group {group_id}.")

            except Exception as e:
                print(f"Error during Vertex AI call or processing for agent {agent_id}: {e}")
                # Optionally send an error message to the group
                error_msg_for_chat = MessageModel(
                    group_id=group_id, sender_id="system", sender_name="System",
                    content=f"Error with agent {agent_profile.name}: Could not generate response."
                )
                await self.manager.broadcast_to_group(group_id, error_msg_for_chat.model_dump_json())


    def _build_vertex_prompt(
        self,
        agent_profile: AgentModel, # Use the imported AgentModel alias
        mission: MissionModel | None,
        conversation_history: List[Dict[str,str]], # List of {"sender_id": id, "sender_name": name, "content": text}
        last_message_from_human: MessageModel
    ) -> str:
        """
        Constructs a prompt for Vertex AI based on agent persona, mission, and conversation history.
        """
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
                # Distinguish between 'You' (the current agent) and others for the LLM's context
                if msg["sender_id"] == agent_profile.agent_id:
                    sender_display = f"You ({agent_profile.name})"
                else:
                    sender_display = msg["sender_name"] # Already resolved to user/other agent name
                prompt_lines.append(f"- {sender_display}: {msg['content']}")

        # The last_message_from_human is already included in conversation_history if it's not the very first message.
        # If it's the trigger, ensure it's clearly marked or the LLM is instructed to respond to the last message.
        # The current history from get_messages_for_group includes the last_human_message.

        prompt_lines.append(f"\nConsidering the information above, your name is {agent_profile.name}. Please provide your response as this agent.")
        prompt_lines.append("Focus on the most recent messages and the overall mission if applicable.")
        prompt_lines.append(f"Respond to the last message from {last_message_from_human.sender_name}: \"{last_message_from_human.content}\"")

        return "\n".join(prompt_lines)
