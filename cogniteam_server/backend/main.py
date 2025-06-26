from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from .utils.firebase_setup import initialize_firebase_admin
from .routers import auth, user, agent, chat_group, chat, insight # agent router module
from .config import settings
from firebase_admin import firestore # Added for on_startup
from .services.agent_service import AgentService # Direct import for AgentService class

# Initialize Firebase Admin SDK on startup (globally)
initialize_firebase_admin()

app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.PROJECT_VERSION,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(auth.router, prefix="/api/v1")
app.include_router(user.router, prefix="/api/v1")
app.include_router(agent.router, prefix="/api/v1") # This is the agent router module
app.include_router(chat_group.router, prefix="/api/v1")
app.include_router(chat.router, prefix="/api/v1")
app.include_router(insight.router, prefix="/api/v1")


@app.get("/api/v1/health", tags=["Health"])
async def health_check():
    return {"status": "ok", "project": settings.PROJECT_NAME, "version": settings.PROJECT_VERSION}

@app.get("/", tags=["Root"])
async def read_root():
    return {"message": f"Welcome to {settings.PROJECT_NAME}!"}

async def on_startup():
    print("Application startup tasks...")
    db = firestore.client()
    # Instantiate AgentService class directly
    agent_service_instance = AgentService(db_client=db)

    print("Ensuring default agents in Firestore...")
    await agent_service_instance.ensure_default_agents()
    print("Default agent check complete.")

async def on_shutdown():
    print("Application shutdown tasks...")

app.add_event_handler("startup", on_startup)
app.add_event_handler("shutdown", on_shutdown)
```
