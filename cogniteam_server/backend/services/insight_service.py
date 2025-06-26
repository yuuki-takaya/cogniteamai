from firebase_admin import firestore
from google.cloud import aiplatform
from typing import List, Dict, Any

from ..config import settings
from ..models import Insight as InsightModel, Message as MessageModel # Pydantic models
from .chat_group_service import ChatGroupService
# from ..utils.firebase_setup import initialize_firebase_admin # Not called directly here
import uuid
from datetime import datetime, timezone

class InsightService:
    _vertex_ai_initialized = False # Class variable to track Vertex AI initialization

    def __init__(self, db_client: firestore.client, chat_group_service: ChatGroupService):
        self.db = db_client
        self.chat_group_service = chat_group_service # Store ChatGroupService instance
        self.vertex_ai_enabled = False

        if not InsightService._vertex_ai_initialized:
            try:
                # Attempt to initialize Vertex AI. This should ideally happen once.
                aiplatform.init(project=settings.VERTEX_AI_PROJECT, location=settings.VERTEX_AI_LOCATION)
                print(f"Vertex AI initialized for InsightService: {settings.VERTEX_AI_PROJECT} in {settings.VERTEX_AI_LOCATION}")
                InsightService._vertex_ai_initialized = True
                self.vertex_ai_enabled = True
            except Exception as e:
                # Check if it's because it's already initialized (might depend on SDK version's error type)
                if "already initialized" in str(e).lower() or (hasattr(aiplatform.initializer, 'global_config') and aiplatform.initializer.global_config.project):
                    print(f"Vertex AI was already initialized (InsightService). Project: {aiplatform.initializer.global_config.project if hasattr(aiplatform.initializer, 'global_config') else 'Unknown'}")
                    InsightService._vertex_ai_initialized = True # Ensure flag is set
                    self.vertex_ai_enabled = True
                else:
                    print(f"Failed to initialize Vertex AI in InsightService: {e}. Insight generation may be limited.")
                    self.vertex_ai_enabled = False # Explicitly set to false if other error
        else:
            # If already initialized by another instance or previous call, just confirm status
            self.vertex_ai_enabled = True if (hasattr(aiplatform.initializer, 'global_config') and aiplatform.initializer.global_config.project) else False
            if self.vertex_ai_enabled:
                 print(f"Vertex AI already initialized, confirmed for InsightService. Project: {aiplatform.initializer.global_config.project if hasattr(aiplatform.initializer, 'global_config') else 'Unknown'}")


    async def generate_insight_for_group(self, group_id: str, insight_type: str = "summary") -> InsightModel | None:
        """
        Generates a specified type of insight for a chat group.
        - Fetches chat history for the group using self.chat_group_service.
        - Uses Vertex AI (placeholder) to generate the insight.
        - Returns an InsightModel.
        """
        chat_history_models: List[MessageModel] = await self.chat_group_service.get_messages_for_group(
            group_id=group_id,
            limit=100 # Adjust limit as needed for context
        )

        if not chat_history_models:
            print(f"No chat history found for group {group_id}. Cannot generate insight.")
            return InsightModel(
                insight_id=str(uuid.uuid4()),
                group_id=group_id,
                insight_text="Not enough data to generate insights. The chat history is empty.",
                insight_type="no_data",
                generated_at=datetime.now(timezone.utc)
            )

        full_chat_text = "\n".join(
            [f"{msg.sender_name or msg.sender_id}: {msg.content}" for msg in chat_history_models]
        )

        insight_text_result = f"Placeholder insight ({insight_type}) for group {group_id} based on recent chat activity."

        if self.vertex_ai_enabled:
            try:
                if insight_type == "summary":
                    insight_text_result = f"Summary of the last {len(chat_history_models)} messages in group {group_id}: Participants discussed various topics. (Vertex AI summary pending)."
                elif insight_type == "sentiment":
                    insight_text_result = f"Overall sentiment of the conversation in group {group_id} appears to be neutral. (Vertex AI sentiment analysis pending)."
                elif insight_type == "keywords":
                    keywords = list(set(word for msg in chat_history_models for word in msg.content.lower().split() if len(word) > 4))[:5]
                    insight_text_result = f"Potential keywords in group {group_id}: {', '.join(keywords)}. (Vertex AI keyword extraction pending)."
                else:
                    insight_text_result = f"A general observation for group {group_id}: The conversation is active. (Vertex AI insight pending)."
            except Exception as e:
                print(f"Error during (placeholder) Vertex AI call for insight generation (group {group_id}, type {insight_type}): {e}")
                insight_text_result = f"Could not generate insight due to a processing error." # More generic error for user
        else:
            print(f"Vertex AI not enabled. Returning placeholder insight for group {group_id}.")

        generated_insight = InsightModel(
            insight_id=str(uuid.uuid4()),
            group_id=group_id,
            insight_text=insight_text_result,
            insight_type=insight_type, # This will be "no_data" if chat_history_models was empty initially
            generated_at=datetime.now(timezone.utc)
        )

        return generated_insight
```
