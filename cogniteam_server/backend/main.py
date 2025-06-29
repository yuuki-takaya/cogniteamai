from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from starlette.middleware.base import BaseHTTPMiddleware
from fastapi.responses import Response
from starlette.requests import Request
from utils.firebase_setup import initialize_firebase_admin
from routers import auth, user, agent, chat_group, chat, insight, simulation
from config import settings

# Initialize Firebase Admin SDK on startup
print("Main: Starting Firebase Admin SDK initialization...")
initialize_firebase_admin()

# Check Firebase Admin SDK initialization
import firebase_admin
print(f"Main: Firebase Admin SDK apps after initialization: {firebase_admin._apps}")
print(f"Main: Default app exists: {firebase_admin._apps.get('[DEFAULT]') is not None}")

class CustomCORSMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        response = await call_next(request)
        
        # Add Access-Control-Allow-Private-Network header for private network requests
        response.headers["Access-Control-Allow-Private-Network"] = "true"
        
        return response

app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.PROJECT_VERSION,
    # You can add other FastAPI parameters here like description, docs_url, etc.
)

# Add custom CORS middleware first
app.add_middleware(CustomCORSMiddleware)

# CORS (Cross-Origin Resource Sharing) configuration
# This allows your Flutter web app (and other specified origins) to make requests to the backend.
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS, # List of allowed origins (e.g., ["http://localhost:3000"])
    allow_credentials=True, # Allows cookies to be included in cross-origin requests
    allow_methods=["*"],    # Allows all standard HTTP methods
    allow_headers=["*"],    # Allows all headers
    expose_headers=["*"],   # Expose all headers to the client
)

# Include routers
app.include_router(auth.router, prefix="/api/v1")
app.include_router(user.router, prefix="/api/v1")
app.include_router(agent.router, prefix="/api/v1")
app.include_router(chat_group.router, prefix="/api/v1")
# app.include_router(chat.router, prefix="/api/v1") # WebSocket routes disabled
app.include_router(insight.router, prefix="/api/v1")
app.include_router(simulation.router, prefix="/api/v1")


@app.get("/api/v1/health", tags=["Health"])
async def health_check():
    """
    A simple health check endpoint to confirm the API is running.
    """
    return {"status": "ok", "project": settings.PROJECT_NAME, "version": settings.PROJECT_VERSION}

@app.get("/", tags=["Root"])
async def read_root():
    return {"message": f"Welcome to {settings.PROJECT_NAME}!"}

# Placeholder for where you might load/initialize other services or ML models if needed
async def on_startup():
    print("Application startup tasks...")
    # Ensure Firebase is initialized (already done globally, but good practice if this were separate)
    # initialize_firebase_admin()
    from firebase_admin import firestore
    from services.agent_service import AgentService # Import here to avoid circular deps if any

    db = firestore.client()
    print("Ensuring default agents in Firestore...")
    await AgentService.ensure_default_agents(db)
    print("Default agent check complete.")
    # Example: Load ML models, connect to other external services

async def on_shutdown():
    print("Application shutdown tasks...")
    # Example: Clean up resources

app.add_event_handler("startup", on_startup)
app.add_event_handler("shutdown", on_shutdown)
