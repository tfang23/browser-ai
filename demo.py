#!/usr/bin/env python3
"""
Demo script to test the agent directly without running the full API.

Usage:
    export FIREWORKS_API_KEY=your_key
    python demo.py "Find the price of iPhone 16 on apple.com"
"""
import asyncio
import sys
import os

# Add parent to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from agent.core import WebAgent


async def main():
    """Run a demo task."""
    api_key = os.getenv("FIREWORKS_API_KEY")
    
    if not api_key:
        print("Error: Set FIREWORKS_API_KEY environment variable")
        print("export FIREWORKS_API_KEY=fw_your_key_here")
        sys.exit(1)
    
    # Get task from command line or use default
    prompt = sys.argv[1] if len(sys.argv) > 1 else "Find the current price of iPhone 16 Pro on apple.com"
    
    print(f"\n{'='*60}")
    print(f"Task: {prompt}")
    print(f"{'='*60}\n")
    
    # Create agent and execute
    agent = WebAgent(fireworks_api_key=api_key)
    
    try:
        result = await agent.execute_task(
            task_id="demo_001",
            prompt=prompt,
            context={"user_name": "Demo User"},
            max_steps=20
        )
        
        print(f"\n{'='*60}")
        print(f"Status: {result['status']}")
        print(f"Duration: {result['duration_seconds']:.2f}s")
        print(f"{'='*60}\n")
        
        if result['success']:
            print(f"✅ Success!")
            print(f"Result: {result['result'][:500]}...")  # Truncate long results
        else:
            print(f"❌ Failed")
            print(f"Error: {result.get('error', 'Unknown error')}")
            
    finally:
        await agent.close()


if __name__ == "__main__":
    asyncio.run(main())
