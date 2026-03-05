"""
Simple tests for the agent system.
Run with: pytest tests/test_agent.py
"""
import pytest
import asyncio
from unittest.mock import Mock, patch

from agent.core import WebAgent, AgentPool


class TestWebAgent:
    """Test WebAgent functionality."""
    
    @pytest.fixture
    def mock_llm(self):
        """Mock LLM for testing."""
        mock = Mock()
        mock.invoke = Mock(return_value="Mocked LLM response")
        return mock
    
    def test_agent_init_requires_api_key(self):
        """Agent should require API key."""
        with patch.dict('os.environ', {}, clear=True):
            with pytest.raises(ValueError, match="FIREWORKS_API_KEY required"):
                WebAgent()
    
    def test_build_task_prompt_with_context(self):
        """Test prompt construction with context."""
        with patch.dict('os.environ', {'FIREWORKS_API_KEY': 'test_key'}):
            agent = WebAgent(fireworks_api_key='test_key')
            
            prompt = "Find cheap flights"
            context = {"origin": "SFO", "destination": "NYC"}
            
            result = agent._build_task_prompt(prompt, context)
            
            assert "Find cheap flights" in result
            assert "origin: SFO" in result
            assert "destination: NYC" in result
    
    def test_build_task_prompt_without_context(self):
        """Test prompt construction without context."""
        with patch.dict('os.environ', {'FIREWORKS_API_KEY': 'test_key'}):
            agent = WebAgent(fireworks_api_key='test_key')
            
            prompt = "Check weather"
            result = agent._build_task_prompt(prompt, None)
            
            assert result == "Check weather"


class TestAgentPool:
    """Test AgentPool concurrency control."""
    
    def test_pool_size(self):
        """Pool should respect size limit."""
        pool = AgentPool(pool_size=5, fireworks_api_key='test')
        assert pool.pool_size == 5
        assert pool._semaphore._value == 5


class TestTaskQueue:
    """Test TaskQueue functionality."""
    
    def test_put_and_get(self):
        """Basic put/get cycle."""
        from scheduler.queue import TaskQueue
        
        queue = TaskQueue()
        task_id = "task_test_123"
        data = {"prompt": "Test task", "status": "pending"}
        
        queue.put(task_id, data, priority=5)
        retrieved = queue.get(task_id)
        
        assert retrieved is not None
        assert retrieved["prompt"] == "Test task"
    
    def test_update_task(self):
        """Task updates should work."""
        from scheduler.queue import TaskQueue
        
        queue = TaskQueue()
        task_id = "task_update_test"
        
        queue.put(task_id, {"status": "pending"}, priority=5)
        queue.update(task_id, {"status": "completed", "result": "done"})
        
        retrieved = queue.get(task_id)
        assert retrieved["status"] == "completed"


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
