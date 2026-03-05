"""
Chat-based task execution and conversational setup.
Simple web chatbot that handles the full flow from prompt to persistent monitoring.
"""
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from typing import Optional, Dict, Any, List
from datetime import datetime
import uuid

from agent.core import AgentPool
from scheduler.persistent import PersistentTask, PersistentTaskScheduler, TaskStatus

router = APIRouter(prefix="/chat", tags=["chat"])

# In-memory state for PoC (use Redis in production)
_conversation_states: Dict[str, Dict] = {}


class ChatMessage(BaseModel):
    user_id: str
    message: str
    session_id: Optional[str] = None


class ChatResponse(BaseModel):
    session_id: str
    response: str
    state: str  # idle, executing, asking_monitor, asking_details, confirming, monitoring
    result: Optional[Dict] = None
    actions: Optional[List[Dict]] = None  # Buttons to show


class ExecuteRequest(BaseModel):
    user_id: str
    prompt: str
    context: Optional[Dict] = None


class MonitorSetupRequest(BaseModel):
    user_id: str
    original_prompt: str
    frequency_minutes: int = Field(default=30, ge=5, le=1440)
    duration_days: int = Field(default=7, ge=1, le=30)
    

@router.post("/message", response_model=ChatResponse)
async def chat_message(msg: ChatMessage):
    """
    Main chat endpoint. Handles the conversational flow for task creation.
    """
    session_id = msg.session_id or f"sess_{uuid.uuid4().hex[:12]}"
    state = _get_conversation_state(session_id)
    
    text = msg.message.lower().strip()
    
    # State: Asking if user wants to monitor after seeing result
    if state.get("phase") == "asking_monitor":
        if any(word in text for word in ["yes", "sure", "monitor", "yes please", "yeah"]):
            _set_conversation_state(session_id, "phase", "asking_frequency")
            return ChatResponse(
                session_id=session_id,
                state="asking_details",
                response="Great! I'll monitor for you. How often should I check?",
                actions=[
                    {"label": "Every 5 min (fast)", "value": "5"},
                    {"label": "Every 30 min (balanced)", "value": "30"},
                    {"label": "Every hour (slow)", "value": "60"}
                ]
            )
        else:
            _set_conversation_state(session_id, "phase", "idle")
            return ChatResponse(
                session_id=session_id,
                state="idle",
                response="No problem! I'm here if you need anything else. Just let me know what you'd like me to do!"
            )
    
    # State: Asking for frequency
    if state.get("phase") == "asking_frequency":
        frequency = _parse_frequency(text)
        state["frequency_minutes"] = frequency
        _set_conversation_state(session_id, "phase", "asking_duration")
        
        return ChatResponse(
            session_id=session_id,
            state="asking_details",
            response=f"Got it - checking every {frequency} minutes. How long should I keep monitoring?",
            actions=[
                {"label": "1 day", "value": "1"},
                {"label": "7 days", "value": "7"},
                {"label": "14 days", "value": "14"},
                {"label": "30 days", "value": "30"}
            ]
        )
    
    # State: Asking for duration
    if state.get("phase") == "asking_duration":
        days = _parse_duration(text)
        frequency = state.get("frequency_minutes", 30)
        
        # Calculate estimated cost
        num_checks = (days * 24 * 60) // frequency
        estimated_tokens = num_checks * 50  # 50 tokens per check
        estimated_usd = estimated_tokens * 0.01
        
        state["duration_days"] = days
        state["estimated_tokens"] = estimated_tokens
        _set_conversation_state(session_id, "phase", "confirming")
        
        return ChatResponse(
            session_id=session_id,
            state="confirming",
            response=f"Perfect! Here's what I'll do:\n\n" +
                    f"✓ Check every {frequency} minutes\n" +
                    f"✓ Monitor for {days} days\n" +
                    f"✓ Use approximately {estimated_tokens} tokens (~${estimated_usd:.2f})\n\n" +
                    f"Ready to start?",
            actions=[
                {"label": "Yes, start monitoring", "value": "yes"},
                {"label": "No, cancel", "value": "no"}
            ]
        )
    
    # State: Confirming task creation
    if state.get("phase") == "confirming":
        if any(word in text for word in ["yes", "sure", "ok", "start", "confirm"]):
            # Create the persistent task
            task = await _create_persistent_task(
                user_id=msg.user_id,
                original_prompt=state.get("original_prompt", "Web monitoring task"),
                frequency=state.get("frequency_minutes", 30),
                duration=state.get("duration_days", 7)
            )
            
            _set_conversation_state(session_id, "phase", "idle")
            _set_conversation_state(session_id, "task_id", task.task_id)
            
            return ChatResponse(
                session_id=session_id,
                state="monitoring",
                response=f"✅ Task created!\n\n" +
                        f"I'm now monitoring every {state.get('frequency_minutes')} minutes for the next {state.get('duration_days')} days. " +
                        f"I'll notify you as soon as I find what you're looking for.\n\n" +
                        f"Estimated token usage: {state.get('estimated_tokens')} tokens.",
                result={"task_id": task.task_id, "status": "monitoring"}
            )
        else:
            _set_conversation_state(session_id, "phase", "idle")
            return ChatResponse(
                session_id=session_id,
                state="idle",
                response="Cancelled. Let me know if you want to try a different configuration or do something else!"
            )
    
    # Default: Execute the task immediately
    return await _execute_task(msg.user_id, session_id, msg.message)


@router.post("/execute", response_model=ChatResponse)
async def execute_task_now(req: ExecuteRequest):
    """
    Execute a one-time task immediately without the conversational flow.
    """
    session_id = f"sess_{uuid.uuid4().hex[:12]}"
    return await _execute_task(req.user_id, session_id, req.prompt, req.context)


async def _execute_task(user_id: str, session_id: str, prompt: str, context: Optional[Dict] = None) -> ChatResponse:
    """
    Execute a web task using the agent.
    """
    # Initialize agent
    from os import getenv
    agent_pool = AgentPool(
        pool_size=1,
        openrouter_api_key=getenv("OPENROUTER_API_KEY")
    )
    
    task_id = f"task_{uuid.uuid4().hex[:12]}"
    
    try:
        # Execute the task
        result = await agent_pool.execute(
            task_id=task_id,
            prompt=prompt,
            context=context
        )
        
        # Format the result for chat
        success = result.get("success", False)
        result_text = result.get("result", "No result available")
        
        # Store result in conversation state
        _set_conversation_state(session_id, "last_result", result)
        _set_conversation_state(session_id, "original_prompt", prompt)
        _set_conversation_state(session_id, "phase", "asking_monitor")
        
        # Determine if we should suggest monitoring
        should_monitor = not success or "sold out" in result_text.lower() or "unavailable" in result_text.lower()
        
        response = f"🔍 I checked that for you. Here's what I found:\n\n{result_text}"
        
        if should_monitor:
            response += "\n\nWould you like me to monitor continuously and notify you when it becomes available?"
            actions = [
                {"label": "Yes, monitor it", "value": "yes"},
                {"label": "No thanks", "value": "no"}
            ]
        else:
            response += "\n\nIs this what you were looking for?"
            actions = [
                {"label": "Yes, perfect!", "value": "yes"},
                {"label": "Keep monitoring", "value": "monitor"},
                {"label": "Try something else", "value": "no"}
            ]
        
        return ChatResponse(
            session_id=session_id,
            response=response,
            state="asking_monitor",
            result={"success": success, "summary": result_text},
            actions=actions
        )
        
    except Exception as e:
        return ChatResponse(
            session_id=session_id,
            response=f"Sorry, I encountered an error while executing your task: {str(e)}. Please try again or try a different request.",
            state="idle",
            result={"success": False, "error": str(e)}
        )


async def _create_persistent_task(user_id: str, original_prompt: str, frequency: int, duration: int) -> PersistentTask:
    """
    Create a persistent monitoring task.
    """
    task_id = f"task_{uuid.uuid4().hex[:12]}"
    
    task = PersistentTask(
        task_id=task_id,
        user_id=user_id,
        task_type="general",
        goal=original_prompt,
        context={},
        check_interval_minutes=frequency,
        expires_at=(datetime.utcnow() + __import__('datetime').timedelta(days=duration)).isoformat(),
        status=TaskStatus.PENDING.value
    )
    
    # In production: Save to database and start scheduler
    # For PoC: Just return the task
    return task


def _get_conversation_state(session_id: str) -> Dict:
    """Get or create conversation state."""
    if session_id not in _conversation_states:
        _conversation_states[session_id] = {"phase": "idle"}
    return _conversation_states[session_id]


def _set_conversation_state(session_id: str, key: str, value: Any):
    """Set a value in conversation state."""
    if session_id not in _conversation_states:
        _conversation_states[session_id] = {"phase": "idle"}
    _conversation_states[session_id][key] = value


def _parse_frequency(text: str) -> int:
    """Parse frequency from user text."""
    text = text.lower()
    if "5" in text or "five" in text:
        return 5
    elif "60" in text or "hour" in text:
        return 60
    elif "15" in text:
        return 15
    else:
        return 30  # default


def _parse_duration(text: str) -> int:
    """Parse duration from user text."""
    text = text.lower()
    if "1" in text and ("day" in text or "24" in text):
        return 1
    elif "14" in text:
        return 14
    elif "30" in text or "month" in text:
        return 30
    else:
        return 7  # default
