from firebase_admin import firestore
from ..models import Agent # Pydantic model
# from ..utils.firebase_setup import initialize_firebase_admin # Not needed directly in methods

class AgentService:

    _system_agents_data_fallback = [
        {
            "agent_id": "fallback_agent_001", "name": "Fallback Friendly Assistant",
            "description": "A friendly and helpful assistant (fallback data).",
            "default_prompt": "You are a friendly and helpful assistant. Always be kind and try to assist the user with their requests."
        },
        {
            "agent_id": "fallback_agent_002", "name": "Fallback Critical Thinker",
            "description": "An agent that thinks critically and asks probing questions (fallback data).",
            "default_prompt": "You are a critical thinker. Analyze information deeply, question assumptions, and provide well-reasoned responses."
        }
    ]

    def __init__(self, db_client: firestore.client):
        self.db = db_client

    async def get_all_agents(self) -> list[Agent]:
        """
        Fetches all agents from the 'agents' collection in Firestore.
        Returns a list of Agent Pydantic models.
        """
        agents_collection = self.db.collection('agents')
        agents_list = []
        try:
            docs_stream = agents_collection.stream()
            for doc in docs_stream:
                agent_data = doc.to_dict()
                if 'agent_id' not in agent_data:
                    agent_data['agent_id'] = doc.id
                agents_list.append(Agent(**agent_data))
            return agents_list
        except Exception as e:
            print(f"Error fetching all agents from Firestore: {e}")
            return []

    async def get_agent_by_id(self, agent_id: str) -> Agent | None:
        """
        Fetches a specific agent by its document ID from the 'agents' collection.
        Returns an Agent Pydantic model if found, None otherwise.
        """
        agents_collection = self.db.collection('agents')
        try:
            doc_ref = agents_collection.document(agent_id)
            doc = doc_ref.get()
            if doc.exists:
                agent_data = doc.to_dict()
                if 'agent_id' not in agent_data:
                    agent_data['agent_id'] = doc.id
                return Agent(**agent_data)
            return None
        except Exception as e:
            print(f"Error fetching agent {agent_id} from Firestore: {e}")
            return None

    async def ensure_default_agents(self):
        """
        Checks if any agents exist in Firestore. If not, populates with fallback data.
        This is an optional utility method, could be called at startup.
        """
        agents_collection = self.db.collection('agents')
        # Use limit(1).get() for a more efficient check if collection is empty
        query_snapshot = agents_collection.limit(1).get() # .get() returns a list of DocumentSnapshot

        if not query_snapshot: # If the list of snapshots is empty
            print("No agents found in Firestore. Populating with default fallback agents...")
            for agent_data_dict in AgentService._system_agents_data_fallback: # Access class variable correctly
                doc_id = agent_data_dict["agent_id"]
                try:
                    agents_collection.document(doc_id).set(agent_data_dict)
                    print(f"Added fallback agent: {doc_id}")
                except Exception as e:
                    print(f"Error adding fallback agent {doc_id}: {e}")
        else:
            print("Agents collection is not empty. Skipping population of fallback agents.")

```
