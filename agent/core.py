"""
Core agent implementation using browser-use + Kimi 2.5 via OpenRouter.
"""
import os
import asyncio
from typing import Optional, Dict, Any
from datetime import datetime

from browser_use import Agent
from browser_use.llm.openrouter.chat import ChatOpenRouter


class WebAgent:
    """
    Autonomous web agent powered by browser-use and Kimi 2.5 via OpenRouter.
    """
    
    def __init__(self, openrouter_api_key: Optional[str] = None):
        self.api_key = openrouter_api_key or os.getenv("OPENROUTER_API_KEY")
        if not self.api_key:
            raise ValueError("OPENROUTER_API_KEY required (get from openrouter.ai)")
        
        # Initialize Kimi 2.5 via OpenRouter
        self.llm = ChatOpenRouter(
            model="moonshotai/kimi-k2.5",
            api_key=self.api_key,
            temperature=0.1,
            max_retries=3,
        )
    
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
            
            # Extract useful info from result
            result_str = str(result)
            if hasattr(result, 'all_results') and result.all_results:
                # Get the last successful extraction
                for r in reversed(result.all_results):
                    if r.extracted_content and not r.error:
                        result_str = r.extracted_content
                        break
            
            return {
                "task_id": task_id,
                "status": "completed",
                "result": result_str,
                "success": True,
                "steps_taken": max_steps,
                "duration_seconds": (datetime.utcnow() - start_time).total_seconds(),
                "timestamp": datetime.utcnow().isoformat(),
            }
            
        except Exception as e:
            import traceback
            return {
                "task_id": task_id,
                "status": "failed",
                "error": str(e),
                "traceback": traceback.format_exc(),
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
        """Cleanup - browser-use handles its own cleanup."""
        pass


class AgentPool:
    """
    Pool of reusable agents for parallel task execution.
    """
    
    def __init__(self, pool_size: int = 3, openrouter_api_key: Optional[str] = None):
        self.pool_size = pool_size
        self.api_key = openrouter_api_key
        self._semaphore = asyncio.Semaphore(pool_size)
    
    async def execute(self, task_id: str, prompt: str, context: Optional[Dict] = None) -> Dict:
        """Execute with concurrency control."""
        async with self._semaphore:
            agent = WebAgent(openrouter_api_key=self.api_key)
            try:
                return await agent.execute_task(task_id, prompt, context)
            finally:
                await agent.close()
