"""
Task queue implementation - Redis-backed with in-memory fallback.
"""
import os
import json
import heapq
from typing import Optional, Dict, Any, List
from datetime import datetime
from dataclasses import dataclass, field
from threading import Lock

try:
    import redis
    REDIS_AVAILABLE = True
except ImportError:
    REDIS_AVAILABLE = False


@dataclass(order=True)
class QueueItem:
    """Priority queue item."""
    priority: int
    timestamp: str = field(compare=True)
    task_id: str = field(compare=False)
    data: Dict = field(compare=False, default_factory=dict)


class TaskQueue:
    """
    Task queue with priority support.
    
    Uses Redis if available, falls back to in-memory for PoC.
    """
    
    def __init__(self):
        self.redis_client: Optional[redis.Redis] = None
        self._memory_store: Dict[str, Dict] = {}
        self._priority_queue: List[QueueItem] = []
        self._lock = Lock()
        
        # Try Redis
        redis_url = os.getenv("REDIS_URL")
        if REDIS_AVAILABLE and redis_url:
            try:
                self.redis_client = redis.from_url(redis_url, decode_responses=True)
                self.redis_client.ping()
                print("Connected to Redis")
            except Exception as e:
                print(f"Redis connection failed: {e}, using in-memory fallback")
                self.redis_client = None
    
    def put(self, task_id: str, data: Dict, priority: int = 5) -> None:
        """Add task to queue."""
        data["task_id"] = task_id
        
        if self.redis_client:
            # Redis storage
            self.redis_client.hset(f"task:{task_id}", mapping={
                "data": json.dumps(data),
                "status": data.get("status", "pending"),
                "priority": priority,
                "created_at": data.get("created_at", datetime.utcnow().isoformat())
            })
            # Add to priority sorted set
            self.redis_client.zadd("task_queue", {task_id: priority})
        else:
            # In-memory storage
            with self._lock:
                self._memory_store[task_id] = data
                item = QueueItem(
                    priority=priority,
                    timestamp=data.get("created_at", datetime.utcnow().isoformat()),
                    task_id=task_id,
                    data=data
                )
                heapq.heappush(self._priority_queue, item)
    
    def get(self, task_id: str) -> Optional[Dict]:
        """Retrieve task by ID."""
        if self.redis_client:
            data = self.redis_client.hget(f"task:{task_id}", "data")
            if data:
                return json.loads(data)
            return None
        else:
            with self._lock:
                return self._memory_store.get(task_id)
    
    def update(self, task_id: str, data: Dict) -> None:
        """Update existing task."""
        self.put(task_id, data, priority=data.get("priority", 5))
    
    def pop_next(self) -> Optional[Dict]:
        """Get highest priority pending task."""
        if self.redis_client:
            # Get from sorted set
            task_ids = self.redis_client.zrange("task_queue", 0, 0)
            if task_ids:
                task_id = task_ids[0].decode() if isinstance(task_ids[0], bytes) else task_ids[0]
                data = self.get(task_id)
                if data and data.get("status") == "pending":
                    return data
            return None
        else:
            with self._lock:
                while self._priority_queue:
                    item = heapq.heappop(self._priority_queue)
                    task_id = item.task_id
                    data = self._memory_store.get(task_id)
                    if data and data.get("status") == "pending":
                        return data
                return None
    
    def list_all(self, limit: int = 20) -> List[Dict]:
        """List all tasks, most recent first."""
        if self.redis_client:
            # Scan for task keys
            tasks = []
            for key in self.redis_client.scan_iter(match="task:*", count=limit):
                task_id = key.decode().split(":")[1] if isinstance(key, bytes) else key.split(":")[1]
                data = self.get(task_id)
                if data:
                    tasks.append(data)
            return sorted(tasks, key=lambda x: x.get("created_at", ""), reverse=True)[:limit]
        else:
            with self._lock:
                tasks = list(self._memory_store.values())
                return sorted(tasks, key=lambda x: x.get("created_at", ""), reverse=True)[:limit]
    
    def count_by_status(self) -> Dict[str, int]:
        """Count tasks by status."""
        all_tasks = self.list_all(limit=10000)
        counts = {}
        for task in all_tasks:
            status = task.get("status", "unknown")
            counts[status] = counts.get(status, 0) + 1
        return counts
