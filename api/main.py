"""
FastAPI web API for task management.
"""
import os
import uuid
from typing import Optional, Dict, Any, List
from datetime import datetime
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, BackgroundTasks, APIRouter
from pydantic import BaseModel, Field

from agent.core import AgentPool
from scheduler.queue import TaskQueue
from scheduler.persistent import PersistentTask, TaskStatus
from api.users import router as users_router


# Global state (simplified for PoC)
agent_pool: Optional[AgentPool] = None
task_queue: Optional[TaskQueue] = None


class TaskCreate(BaseModel):
    prompt: str = Field(..., description="Natural language task description")
    context: Optional[Dict[str, Any]] = Field(default=None, description="Additional context")
    priority: int = Field(default=5, ge=1, le=10, description="Task priority (1-10)")


class TaskResponse(BaseModel):
    task_id: str
    status: str  # pending, running, completed, failed, needs_input
    prompt: str
    result: Optional[str] = None
    error: Optional[str] = None
    created_at: str
    updated_at: str
    cost_estimate: Optional[float] = None


class HumanResponse(BaseModel):
    response: str = Field(..., description="User's response to agent question")


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup/shutdown events."""
    global agent_pool, task_queue
    
    # Initialize on startup
    agent_pool = AgentPool(
        pool_size=int(os.getenv("AGENT_POOL_SIZE", "3")),
        openrouter_api_key=os.getenv("OPENROUTER_API_KEY")
    )
    task_queue = TaskQueue()
    
    yield
    
    # Cleanup on shutdown
    if agent_pool:
        pass  # Cleanup if needed


app = FastAPI(
    title="Web Agent API",
    description="AI-powered web automation using browser-use + Kimi 2.5",
    version="0.2.0",
    lifespan=lifespan
)

# Include user management routes
app.include_router(users_router)


def _generate_task_id() -> str:
    """Generate unique task ID."""
    return f"task_{uuid.uuid4().hex[:12]}"


async def _execute_task(task_id: str, prompt: str, context: Optional[Dict]):
    """Background task execution."""
    result = await agent_pool.execute(task_id, prompt, context)
    
    # Update task in queue
    task = task_queue.get(task_id)
    if task:
        task["status"] = result["status"]
        task["result"] = result.get("result")
        task["error"] = result.get("error")
        task["updated_at"] = datetime.utcnow().isoformat()
        task_queue.update(task_id, task)


@app.post("/tasks", response_model=TaskResponse)
async def create_task(task: TaskCreate, background_tasks: BackgroundTasks):
    """
    Create a new web automation task.
    
    The task will be queued and executed by an available agent.
    """
    task_id = _generate_task_id()
    
    # Store in queue
    task_data = {
        "task_id": task_id,
        "prompt": task.prompt,
        "context": task.context or {},
        "status": "pending",
        "priority": task.priority,
        "created_at": datetime.utcnow().isoformat(),
        "updated_at": datetime.utcnow().isoformat(),
        "result": None,
        "error": None,
        "cost_estimate": 0.5,  # Placeholder: $0.50 estimated
    }
    task_queue.put(task_id, task_data, priority=task.priority)
    
    # Start execution in background
    background_tasks.add_task(_execute_task, task_id, task.prompt, task.context)
    
    return TaskResponse(
        task_id=task_id,
        status="pending",
        prompt=task.prompt,
        created_at=task_data["created_at"],
        updated_at=task_data["updated_at"],
        cost_estimate=task_data["cost_estimate"]
    )


@app.get("/tasks/{task_id}", response_model=TaskResponse)
async def get_task(task_id: str):
    """Get task status and result."""
    task = task_queue.get(task_id)
    
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")
    
    return TaskResponse(
        task_id=task["task_id"],
        status=task["status"],
        prompt=task["prompt"],
        result=task.get("result"),
        error=task.get("error"),
        created_at=task["created_at"],
        updated_at=task["updated_at"],
        cost_estimate=task.get("cost_estimate")
    )


@app.post("/tasks/{task_id}/respond", response_model=TaskResponse)
async def respond_to_task(task_id: str, response: HumanResponse):
    """
    Provide human input when agent needs assistance (CAPTCHA, 2FA, etc.).
    
    For PoC: This marks the task for retry with additional context.
    """
    task = task_queue.get(task_id)
    
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")
    
    # Add response to context
    task["context"] = task.get("context", {})
    task["context"]["human_response"] = response.response
    task["status"] = "pending"  # Re-queue for retry
    task["updated_at"] = datetime.utcnow().isoformat()
    task_queue.update(task_id, task)
    
    return TaskResponse(
        task_id=task["task_id"],
        status=task["status"],
        prompt=task["prompt"],
        created_at=task["created_at"],
        updated_at=task["updated_at"]
    )


@app.get("/tasks", response_model=List[TaskResponse])
async def list_tasks(limit: int = 20):
    """List recent tasks."""
    tasks = task_queue.list_all(limit=limit)
    
    return [
        TaskResponse(
            task_id=t["task_id"],
            status=t["status"],
            prompt=t["prompt"],
            result=t.get("result"),
            error=t.get("error"),
            created_at=t["created_at"],
            updated_at=t["updated_at"],
            cost_estimate=t.get("cost_estimate")
        )
        for t in tasks
    ]


@app.get("/health")
async def health_check():
    """Health check endpoint."""
    return {
        "status": "healthy",
        "agent_pool_ready": agent_pool is not None,
        "queue_ready": task_queue is not None,
        "timestamp": datetime.utcnow().isoformat()
    }
