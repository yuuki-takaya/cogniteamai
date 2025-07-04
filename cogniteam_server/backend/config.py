# Configuration settings for the application
import os
from typing import Optional
from dotenv import load_dotenv

# Load environment variables from .env file if it exists
load_dotenv()

class Settings:
    PROJECT_NAME: str = "CogniTeamAI Server"
    PROJECT_VERSION: str = "0.1.0"

    # Firebase settings
    # Priority 1: GOOGLE_APPLICATION_CREDENTIALS environment variable (recommended for cloud environments)
    # This variable's presence is checked directly by the Firebase Admin SDK if no explicit credential is passed.
    # Priority 2: FIREBASE_SERVICE_ACCOUNT_KEY_PATH environment variable (for local development or specific setups)
    FIREBASE_SERVICE_ACCOUNT_KEY_PATH: Optional[str] = os.getenv("FIREBASE_SERVICE_ACCOUNT_KEY_PATH")

    # Vertex AI Settings
    VERTEX_AI_PROJECT: str = os.getenv("VERTEX_AI_PROJECT", "your-gcp-project-id")
    VERTEX_AI_LOCATION: str = os.getenv("VERTEX_AI_LOCATION", "us-central1")
    # Specific model names can also be configured here
    VERTEX_AI_CHAT_MODEL_NAME: str = os.getenv("VERTEX_AI_CHAT_MODEL_NAME", "gemini-1.0-pro") # Example
    VERTEX_AI_INSIGHT_MODEL_NAME: str = os.getenv("VERTEX_AI_INSIGHT_MODEL_NAME", "text-bison@002") # Example

    # Google AI Agent Settings
    GOOGLE_AI_AGENT_MODEL: str = os.getenv("GOOGLE_AI_AGENT_MODEL", "gemini-2.0-flash")
    VERTEX_AI_AGENT_ENGINE_ENABLED: bool = os.getenv("VERTEX_AI_AGENT_ENGINE_ENABLED", "true").lower() == "true"
    VERTEX_AI_AGENT_ENGINE_SKIP_CREATION: bool = os.getenv("VERTEX_AI_AGENT_ENGINE_SKIP_CREATION", "false").lower() == "true"
    GOOGLE_API_KEY: str = os.getenv("GOOGLE_API_KEY", "")

    # Vertex AI Agent Engine Settings (based on Google Cloud documentation)
    VERTEX_AI_STAGING_BUCKET: str = os.getenv("VERTEX_AI_STAGING_BUCKET", f"gs://{VERTEX_AI_PROJECT}-agent-staging")
    VERTEX_AI_AGENT_ENGINE_FRAMEWORK: str = os.getenv("VERTEX_AI_AGENT_ENGINE_FRAMEWORK", "langchain")  # Options: langchain, adk, ag2, llama_index
    VERTEX_AI_AGENT_ENGINE_DEPLOYMENT_TIMEOUT: int = int(os.getenv("VERTEX_AI_AGENT_ENGINE_DEPLOYMENT_TIMEOUT", "300"))  # 5 minutes default

    # API keys (should always be from environment variables)
    # EXAMPLE_API_KEY: str = os.getenv("EXAMPLE_API_KEY")

    # JWT Settings (if implementing custom JWTs, not relying solely on Firebase ID tokens for session)
    # SECRET_KEY: str = os.getenv("SECRET_KEY", "a_very_secret_key_that_should_be_random_and_long") # Replace with a strong, random key
    # ALGORITHM: str = "HS256"
    # ACCESS_TOKEN_EXPIRE_MINUTES: int = 30 # Example: 30 minutes

    # CORS settings (Cross-Origin Resource Sharing)
    # List of allowed origins. Use ["*"] for allowing all, but be specific for production.
    ALLOWED_ORIGINS: list[str] = os.getenv("ALLOWED_ORIGINS", "*").split(',')
    # If ALLOWED_ORIGINS is not set or empty, default to a restrictive or common dev setup.
    if not ALLOWED_ORIGINS or ALLOWED_ORIGINS == ['']:
        # Default origins for development and production
        ALLOWED_ORIGINS = [
            "http://localhost:3000",
            "http://localhost:8080", 
            "https://handsonadk.web.app",
            "https://handsonadk.firebaseapp.com"
        ]


settings = Settings()

# Example of how to use in other files:
# from .config import settings
# print(settings.PROJECT_NAME)
# if settings.FIREBASE_SERVICE_ACCOUNT_KEY_PATH:
#     print(f"Service account key path: {settings.FIREBASE_SERVICE_ACCOUNT_KEY_PATH}")

pass
