"""
Persistent task scheduler for recurring web automation.

Example use case:
- User: "Book me a table for 4 at Fu Hui Hua"
- Agent checks every 30 minutes
- When available → immediately books
- When sold out → schedules next check
"""
import os
import asyncio
import json
from typing import Optional, Dict, Any, Callable
from datetime import datetime, timedelta
from dataclasses import dataclass, asdict
from enum import Enum

from scheduler.queue import TaskQueue


class TaskStatus(Enum):
    PENDING = "pending"           # Waiting for first check
    MONITORING = "monitoring"     # Actively checking periodically  
    AVAILABLE = "available"       # Slot found, ready to book
    BOOKING = "booking"           # Currently attempting booking
    COMPLETED = "completed"       # Successfully booked
    FAILED = "failed"             # Terminal failure
    EXPIRED = "expired"           # User deadline passed


@dataclass
class PersistentTask:
    """
    A task that persists and runs until completion or expiration.
    """
    task_id: str
    user_id: str
    
    # Task definition
    task_type: str  # "restaurant_reservation", "event_ticket", "flight_booking"
    goal: str  # Natural language goal: "Book Fu Hui Hua for 4 people"
    
    # Context needed for booking
    context: Dict[str, Any]  # {party_size: 4, name: "John", phone: "...", preferences: {...}}
    
    # Scheduling
    status: str = "pending"
    check_interval_minutes: int = 30  # How often to check
    next_check_at: Optional[str] = None
    
    # Time bounds
    created_at: str = ""
    expires_at: Optional[str] = None  # "2026-03-12T23:59:59Z" - stop trying after this
    
    # Results
    last_check_at: Optional[str] = None
    last_check_result: Optional[str] = None  # "sold_out", "available", "error", etc.
    booking_attempts: int = 0
    success_result: Optional[Dict] = None
    failure_reason: Optional[str] = None
    
    def __post_init__(self):
        if not self.created_at:
            self.created_at = datetime.utcnow().isoformat()
        if not self.next_check_at:
            self.schedule_next_check()
    
    def schedule_next_check(self, minutes: Optional[int] = None):
        """Schedule the next check time."""
        interval = minutes or self.check_interval_minutes
        next_time = datetime.utcnow() + timedelta(minutes=interval)
        self.next_check_at = next_time.isoformat()
    
    def to_dict(self) -> Dict:
        return asdict(self)
    
    @classmethod
    def from_dict(cls, data: Dict) -> 'PersistentTask':
        return cls(**data)


class PersistentTaskScheduler:
    """
    Schedules and executes persistent monitoring tasks.
    
    For each task:
    1. Check if goal is achievable now
    2. If YES → execute immediately → mark complete
    3. If NO → schedule next check → continue monitoring
    4. If EXPIRED → mark failed
    """
    
    def __init__(self, queue: Optional[TaskQueue] = None):
        self.queue = queue or TaskQueue()
        self.running = False
        self._handlers: Dict[str, Callable] = {}
    
    def register_handler(self, task_type: str, handler: Callable):
        """Register a handler function for a task type."""
        self._handlers[task_type] = handler
    
    async def run(self):
        """Main scheduler loop."""
        self.running = True
        print(f"[{datetime.utcnow().isoformat()}] Scheduler started")
        
        while self.running:
            try:
                # Find tasks that need checking
                due_tasks = self._get_due_tasks()
                
                for task_dict in due_tasks:
                    task = PersistentTask.from_dict(task_dict)
                    
                    # Skip if expired
                    if self._is_expired(task):
                        task.status = TaskStatus.EXPIRED.value
                        task.failure_reason = "Task expired"
                        self._save_task(task)
                        print(f"[{task.task_id}] EXPIRED")
                        continue
                    
                    # Execute check
                    print(f"[{task.task_id}] Checking: {task.goal}")
                    result = await self._execute_check(task)
                    
                    # Handle result
                    if result.get("available"):
                        # Book it!
                        print(f"[{task.task_id}] AVAILABLE! Booking now...")
                        task.status = TaskStatus.BOOKING.value
                        self._save_task(task)
                        
                        booking_result = await self._execute_booking(task)
                        
                        if booking_result.get("success"):
                            task.status = TaskStatus.COMPLETED.value
                            task.success_result = booking_result
                            print(f"[{task.task_id}] ✅ BOOKED!")
                            # TODO: Send notification to user
                        else:
                            # Booking failed, continue monitoring
                            task.booking_attempts += 1
                            task.last_check_result = "booking_failed"
                            task.status = TaskStatus.MONITORING.value
                            task.schedule_next_check(minutes=5)  # Retry sooner
                            print(f"[{task.task_id}] Booking failed, will retry")
                            self._save_task(task)
                    
                    elif result.get("status") == "sold_out":
                        # Keep monitoring
                        task.status = TaskStatus.MONITORING.value
                        task.last_check_result = "sold_out"
                        task.last_check_at = datetime.utcnow().isoformat()
                        task.schedule_next_check()
                        print(f"[{task.task_id}] Sold out, checking again at {task.next_check_at}")
                        self._save_task(task)
                    
                    else:
                        # Some other state, keep monitoring
                        task.last_check_result = result.get("status", "unknown")
                        task.schedule_next_check()
                        self._save_task(task)
                
                # Sleep before next poll
                await asyncio.sleep(10)  # Check queue every 10 seconds
                
            except Exception as e:
                print(f"[Scheduler Error] {e}")
                await asyncio.sleep(30)
    
    def _get_due_tasks(self) -> list:
        """Get all tasks where next_check_at <= now."""
        now = datetime.utcnow().isoformat()
        all_tasks = self.queue.list_all(limit=1000)
        
        due = []
        for task_dict in all_tasks:
            next_check = task_dict.get("next_check_at")
            status = task_dict.get("status")
            
            # Only check pending/monitoring tasks that are due
            if status in [TaskStatus.PENDING.value, TaskStatus.MONITORING.value]:
                if next_check and next_check <= now:
                    due.append(task_dict)
        
        return due
    
    def _is_expired(self, task: PersistentTask) -> bool:
        """Check if task has passed its expiration time."""
        if not task.expires_at:
            return False
        return datetime.utcnow() > datetime.fromisoformat(task.expires_at)
    
    async def _execute_check(self, task: PersistentTask) -> Dict:
        """
        Execute a check to see if the goal is achievable.
        Returns: {"available": True/False, "status": "...", "details": {...}}
        """
        handler = self._handlers.get(task.task_type)
        if not handler:
            return {"available": False, "status": "no_handler", "error": f"No handler for {task.task_type}"}
        
        try:
            # Call the handler with task info
            # Handler should quickly check availability (not actually book)
            result = await handler(task, action="check")
            return result
        except Exception as e:
            return {"available": False, "status": "error", "error": str(e)}
    
    async def _execute_booking(self, task: PersistentTask) -> Dict:
        """
        Execute the actual booking.
        This is where the agent books the reservation/ticket/etc.
        """
        handler = self._handlers.get(task.task_type)
        if not handler:
            return {"success": False, "error": f"No handler for {task.task_type}"}
        
        try:
            # Call handler with action="book"
            result = await handler(task, action="book")
            return result
        except Exception as e:
            return {"success": False, "error": str(e)}
    
    def _save_task(self, task: PersistentTask):
        """Persist task to queue."""
        self.queue.update(task.task_id, task.to_dict())
    
    def create_task(self, task: PersistentTask) -> str:
        """Create a new persistent task."""
        self.queue.put(task.task_id, task.to_dict(), priority=5)
        print(f"[{task.task_id}] Created: {task.goal}")
        return task.task_id
    
    def stop(self):
        """Stop the scheduler."""
        self.running = False


# Example handler for restaurant reservations
async def restaurant_reservation_handler(task: PersistentTask, action: str) -> Dict:
    """
    Handler for restaurant reservation tasks.
    
    action="check": Quickly check if reservations available
    action="book": Actually book the reservation
    """
    from agent.core import WebAgent
    
    # Parse the goal to extract restaurant name
    # In production, this would be more robust
    goal_lower = task.goal.lower()
    
    # Extract restaurant name from goal (simple parsing)
    # "Book me a table for 4 at Fu Hui Hua" → "Fu Hui Hua"
    restaurant_name = "Fu Hui Hua"  # TODO: better parsing
    party_size = task.context.get("party_size", 4)
    
    agent = WebAgent(openrouter_api_key=os.getenv("OPENROUTER_API_KEY"))
    
    try:
        if action == "check":
            # Quick check: Is anything available?
            result = await agent.execute_task(
                task_id=f"{task.task_id}_check",
                prompt=f"Check if reservations are available at {restaurant_name} in San Francisco for {party_size} people. "
                       f"Look at Tock or their reservation system. "
                       f"If sold out, just report 'sold_out'. "
                       f"If available slots exist, report 'available' and list the times.",
                context={"party_size": party_size},
                max_steps=15  # Quick check
            )
            
            result_text = result.get("result", "").lower()
            
            if "sold out" in result_text or "unavailable" in result_text:
                return {"available": False, "status": "sold_out"}
            elif "available" in result_text:
                return {"available": True, "status": "available", "details": result}
            else:
                return {"available": False, "status": "unclear", "raw_result": result}
        
        elif action == "book":
            # Actually book it
            user_context = "\n".join([f"- {k}: {v}" for k, v in task.context.items()])
            
            result = await agent.execute_task(
                task_id=f"{task.task_id}_book",
                prompt=f"Book a reservation at {restaurant_name} for {party_size} people. "
                       f"Use this information to fill the form:\n{user_context}\n"
                       f"Complete the entire booking flow including selecting time and entering details.",
                context=task.context,
                max_steps=30  # More steps for full booking
            )
            
            # Check if booking succeeded
            result_text = result.get("result", "").lower()
            
            if result.get("success") and ("confirmed" in result_text or "booked" in result_text):
                return {"success": True, "confirmation": result.get("result"), "details": result}
            else:
                return {"success": False, "error": result.get("error"), "details": result}
        
        else:
            return {"error": f"Unknown action: {action}"}
    
    finally:
        await agent.close()
