import vertexai
from google.adk.agents import Agent
from vertexai import agent_engines
from vertexai.preview.reasoning_engines import AdkApp
from config import settings
import json
import uuid
import google.generativeai as genai
import asyncio

class AgentEngineService:
    """
    Service for creating Google AI Agents and registering them with Vertex AI Agent Engine
    """
    
    def __init__(self):
        self.project_id = settings.VERTEX_AI_PROJECT
        self.location = settings.VERTEX_AI_LOCATION
        
        print(f"AgentEngineService: Initializing with project: {self.project_id}, location: {self.location}")
        print(f"AgentEngineService: VERTEX_AI_AGENT_ENGINE_ENABLED: {settings.VERTEX_AI_AGENT_ENGINE_ENABLED}")
        print(f"AgentEngineService: GOOGLE_API_KEY set: {bool(settings.GOOGLE_API_KEY)}")
        print(f"AgentEngineService: GOOGLE_AI_AGENT_MODEL: {settings.GOOGLE_AI_AGENT_MODEL}")
        
        # Initialize Google Generative AI
        if settings.GOOGLE_API_KEY:
            genai.configure(api_key=settings.GOOGLE_API_KEY)
            print("AgentEngineService: Google Generative AI configured with API key")
        else:
            print("AgentEngineService: Warning: GOOGLE_API_KEY not set. Agent creation may not work properly.")
        
        # Initialize Vertex AI with Agent Engine support
        try:
            staging_bucket = f"gs://{self.project_id}-agent-staging"
            print(f"AgentEngineService: Using staging bucket: {staging_bucket}")
            
            vertexai.init(
                project=self.project_id,
                location=self.location,
                staging_bucket=staging_bucket
            )
            print(f"AgentEngineService: Vertex AI initialized for project: {self.project_id} in location: {self.location}")
        except Exception as e:
            print(f"AgentEngineService: Warning: Failed to initialize Vertex AI: {e}")
            print(f"AgentEngineService: This may prevent agent deployment to Vertex AI Agent Engine")
    
    async def create_google_ai_agent(self, name: str, description: str, instruction: str) -> Agent:
        """
        Create a Google AI Agent using the Generative AI API
        
        Args:
            name: Agent name
            description: Agent description
            instruction: Agent instruction/prompt
            
        Returns:
            Agent: The created Google AI Agent object
        """
        try:
            print(f"AgentEngineService: Creating Google AI Agent with name: {name}")
            print(f"AgentEngineService: Using model: {settings.GOOGLE_AI_AGENT_MODEL}")
            
            # Store agent information (in a real implementation, this would be in a database)
            agent_info = {
                "name": name,
                "description": description,
                "instruction": instruction,
                "model": settings.GOOGLE_AI_AGENT_MODEL
            }

            print(f"AgentEngineService: Agent info prepared: {agent_info}")
            
            agent = Agent(
                name=name,
                model=settings.GOOGLE_AI_AGENT_MODEL,
                description=(description),
                instruction=(instruction),
            )
            
            print(f"AgentEngineService: Successfully created Google AI Agent: {agent}")
            print(f"AgentEngineService: Agent name: {agent.name}")
            print(f"AgentEngineService: Agent model: {agent.model}")
            
            return agent
            
        except Exception as e:
            print(f"AgentEngineService: Error creating Google AI Agent: {e}")
            print(f"AgentEngineService: Error type: {type(e)}")
            import traceback
            print(f"AgentEngineService: Full traceback: {traceback.format_exc()}")
            raise Exception(f"Failed to create Google AI Agent: {str(e)}")
    
    async def register_agent_with_vertex_ai_engine(self, agent: Agent, display_name: str, description: str) -> dict | str:
        """
        Register the created agent with Vertex AI Agent Engine
        
        Args:
            agent: The Google AI Agent object
            display_name: Agent display name
            description: Agent description
            
        Returns:
            dict | str: The deployment result or endpoint URL
        """
        try:
            print(f"AgentEngineService: Starting agent deployment for: {agent.name}")
            print(f"AgentEngineService: Attempting to register agent {agent.name} with Vertex AI Agent Engine...")

            # Initialize remote_app variable
            remote_app = None
            
            # Deploy to Agent Engine - try different approaches
            try:
                # Method 1: Pass agent directly without requirements file
                print(f"AgentEngineService: Method 1 - Deploying agent directly...")
                
                # Set a timeout for the deployment process
                print(f"AgentEngineService: Starting deployment with 10-minute timeout...")
                remote_app = await asyncio.wait_for(
                    asyncio.to_thread(
                        agent_engines.create,
                        agent,
                        requirements="agent_requirements.txt",
                        display_name=display_name,
                        description=description,
                    ),
                    timeout=600.0  # 10 minutes timeout for deployment
                )
                print(f"AgentEngineService: Deployment completed successfully")
            except asyncio.TimeoutError:
                print(f"AgentEngineService: Method 1 timed out after 10 minutes")
                remote_app = None
            except Exception as e:
                print(f"Method 1 failed: {e}")
                remote_app = None

            # Check if deployment was successful
            if remote_app is not None:
                print(f"AgentEngineService: Deployment successful, remote_app: {remote_app}")
                return {
                    "status": "success",
                    "agent_name": remote_app.name,
                    "resource_name": remote_app.resource_name
                }
            else:
                print(f"AgentEngineService: All deployment methods failed")
                raise Exception("All deployment methods failed")

        except Exception as e:
            print(f"AgentEngineService: Error registering agent with Vertex AI Agent Engine: {e}")
            print(f"AgentEngineService: Error type: {type(e)}")
            import traceback
            print(f"AgentEngineService: Full traceback: {traceback.format_exc()}")
            
            # For now, return a placeholder endpoint URL
            # In a real implementation, this would be the actual endpoint
            placeholder_endpoint = f"https://{self.location}-{self.project_id}.run.app/agents/{agent.name}"
            print(f"AgentEngineService: Using placeholder endpoint: {placeholder_endpoint}")
            return placeholder_endpoint
    
    async def create_and_register_agent(self, name: str, description: str, instruction: str) -> dict:
        """
        Create a Google AI Agent and register it with Vertex AI Agent Engine
        
        Args:
            name: Agent name
            description: Agent description
            instruction: Agent instruction/prompt
            
        Returns:
            dict: Contains agent_id and endpoint_url
        """
        try:
            print(f"AgentEngineService: Starting create_and_register_agent for: {name}")
            print(f"AgentEngineService: Description: {description[:100]}...")
            print(f"AgentEngineService: Instruction length: {len(instruction)}")
            
            # Step 1: Create Google AI Agent
            print(f"AgentEngineService: Step 1 - Creating Google AI Agent...")
            agent = await self.create_google_ai_agent(name, description, instruction)
            print(f"AgentEngineService: Step 1 completed - Agent created: {agent.name}")
            
            # Step 2: Register with Vertex AI Agent Engine
            print(f"AgentEngineService: Step 2 - Registering with Vertex AI Agent Engine...")
            deployment_result = await self.register_agent_with_vertex_ai_engine(agent, name, description)
            print(f"AgentEngineService: Step 2 completed - Deployment result: {deployment_result}")
            
            # Extract endpoint URL from deployment result
            if isinstance(deployment_result, dict) and deployment_result.get("status") == "success":
                # Use the resource name to construct the endpoint URL
                resource_name = deployment_result.get("resource_name", "")
                agent_name = deployment_result.get("agent_name", agent.name)
                endpoint_url = f"https://projects/{self.project_id}/locations/{self.location}/reasoningEngines/{resource_name}"
                agent_id = agent_name
                print(f"AgentEngineService: Successfully deployed agent to: {agent_name}")
                print(f"AgentEngineService: Successfully deployed agent to: {agent_id}")
                print(f"AgentEngineService: Successfully deployed agent to: {endpoint_url}")
            else:
                # Fallback to placeholder endpoint
                endpoint_url = deployment_result if isinstance(deployment_result, str) else f"https://{self.location}-{self.project_id}.run.app/agents/{agent.name}"
                agent_id = agent.name  # Use agent name as fallback ID
                print(f"AgentEngineService: Using fallback endpoint: {endpoint_url}")
            
            result = {
                "agent_id": agent_id,
                "endpoint_url": endpoint_url,
                "deployment_result": deployment_result
            }
            print(f"AgentEngineService: Final result: {result}")
            return result
            
        except Exception as e:
            print(f"AgentEngineService: Error in create_and_register_agent: {e}")
            print(f"AgentEngineService: Error type: {type(e)}")
            import traceback
            print(f"AgentEngineService: Full traceback: {traceback.format_exc()}")
            raise Exception(f"Failed to create and register agent: {str(e)}") 