"""
Core agent implementation using browser-use + Kimi 2.5 on Fireworks.
"""
import os
import asyncio
from typing import Optional, Dict, Any
from datetime import datetime

from browser_use import Agent, Browser, BrowserConfig
from langchain_fireworks import ChatFireworks


class WebAgent:
    """
    Autonomous web agent powered by browser-use and Kimi 2.5.
    """
    
    def __init__(self, fireworks_api_key: Optional[str] = None):
        self.api_key = fireworks_api_key or os.getenv("FIREWORKS_API_KEY")
        if not self.api_key:
            raise ValueError("FIREWORKS_API_KEY required")
        
        # Initialize Kimi 2.5 via Fireworks
        self.llm = ChatFireworks(
            model="accounts/fireworks/models/kimi-k2p5",
            api_key=self.api_key,
            temperature=0.1,
            max_tokens=4096,
        )
        
        # Browser will be initialized per-task for isolation
        self._browser: Optional[Browser] = None
    
    async def execute_task(
        self, 
        task_id: str,
        prompt: str,
        context: Optional[Dict[str, Any]] = None,
        max_steps: int = 25
    ) -> Dict[str, Any]:
        """
        Execute a web task autonomously.
        
        Args:
            task_id: Unique task identifier
            prompt: Natural language task description
            context: Additional context (user info, preferences)
            max_steps: Maximum browser actions before timeout
            
        Returns:
            Dict with result, status, and metadata
        """
        start_time = datetime.utcnow()
        
        try:
            # Build browser-use agent
            agent = Agent(
                task=self._build_task_prompt(prompt, context),
                llm=self.llm,
                use_vision=True,  # Enable visual understanding
                max_failures=3,
            )
            
            # Execute
            result = await agent.run(max_steps=max_steps)
            
            return {
                "task_id": task_id,
                "status": "completed",
                "result": str(result),
                "success": True,
                "steps_taken": max_steps,  # browser-use tracks this internally
                "duration_seconds": (datetime.utcnow() - start_time).total_seconds(),
                "timestamp": datetime.utcnow().isoformat(),
            }
            
        except Exception as e:
            return {
                "task_id": task_id,
                "status": "failed",
                "error": str(e),
                "success": False,
                "duration_seconds": (datetime.utcnow() - start_time).total_seconds(),
                "timestamp": datetime.utcnow().isoformat(),
            }
    
    def _build_task_prompt(self, prompt: str, context: Optional[Dict]) -> str:
        """Combine user prompt with context."""
        base = prompt
        
        if context:
            context_str = "\n".join([f"- {k}: {v}" for k, v in context.items()])
            base += f"\n\nAdditional context:\n{context_str}"
        
        return base
    
    async def close(self):
        """Cleanup browser resources."""
        if self._browser:
            await self._browser.close()


class AgentPool:
    """
    Pool of reusable agents for parallel task execution.
    """
    
    def __init__(self, pool_size: int = 3, fireworks_api_key: Optional[str] = None):
        self.pool_size = pool_size
        self.api_key = fireworks_api_key
        self._semaphore = asyncio.Semaphore(pool_size)
    
    async def execute(self, task_id: str, prompt: str, context: Optional[Dict] = None) -> Dict:
        """Execute with concurrency control."""
        async with self._semaphore:
            agent = WebAgent(fireworks_api_key=self.api_key)
            try:
                return await agent.execute_task(task_id, prompt, context)
            finally:
                await agent.close()
