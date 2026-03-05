# POC Agent - AI Web Automation

A proof-of-concept backend for autonomous web agents using **browser-use** and **Kimi 2.5** on Fireworks.

## Architecture

```
iOS App (Thin Client)
    ↓ HTTP/WebSocket
FastAPI Server
    ↓
Task Queue (Redis or in-memory)
    ↓
Agent Pool (3 concurrent workers)
    ↓
browser-use + Playwright + Kimi 2.5
```

## Quick Start

### 1. Install Dependencies

```bash
# Create virtual environment
python -m venv venv
source venv/bin/activate  # or `venv\Scripts\activate` on Windows

# Install Python packages
pip install -r requirements.txt

# Install Playwright browsers
playwright install chromium
```

### 2. Set Environment Variables

Create `.env` file:

```bash
FIREWORKS_API_KEY=your_fireworks_api_key_here
REDIS_URL=redis://localhost:6379/0  # Optional - falls back to in-memory
AGENT_POOL_SIZE=3
```

### 3. Run the API Server

```bash
cd poc-agent
uvicorn api.main:app --reload --host 0.0.0.0 --port 8000
```

### 4. Test the API

```bash
# Health check
curl http://localhost:8000/health

# Create a task
curl -X POST http://localhost:8000/tasks \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "Find the price of iPhone 16 Pro on apple.com",
    "context": {"user_name": "Test User"}
  }'

# Response:
# {"task_id":"task_abc123","status":"pending","prompt":"..."}

# Check task status
curl http://localhost:8000/tasks/task_abc123

# List all tasks
curl http://localhost:8000/tasks?limit=10
```

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/tasks` | Create new web automation task |
| GET | `/tasks/{id}` | Get task status and result |
| POST | `/tasks/{id}/respond` | Provide human input (CAPTCHA, etc.) |
| GET | `/tasks` | List recent tasks |
| GET | `/health` | Health check |

## Task Lifecycle

1. **User submits task** via iOS app → stored in queue with `pending` status
2. **Background worker** picks up task → spins up browser-use agent with Kimi 2.5
3. **Agent executes** → browses web, extracts information, completes goal
4. **Result stored** → task marked `completed` or `failed`
5. **Push notification** sent to iOS app (not implemented in PoC)

## Demo Tasks to Try

```bash
# Simple price check
curl -X POST http://localhost:8000/tasks -H "Content-Type: application/json" -d '{
  "prompt": "Go to amazon.com and find the current price of Kindle Paperwhite"
}'

# Restaurant search
curl -X POST http://localhost:8000/tasks -H "Content-Type: application/json" -d '{
  "prompt": "Check resy.com for available reservations at State Bird Provisions San Francisco tonight at 7pm or 8pm",
  "context": {"party_size": 2}
}'

# Flight search
curl -X POST http://localhost:8000/tasks -H "Content-Type: application/json" -d '{
  "prompt": "Check united.com for flights from SFO to JFK tomorrow morning"
}'
```

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `FIREWORKS_API_KEY` | Required | API key for Kimi 2.5 |
| `REDIS_URL` | None | Redis connection string (in-memory if not set) |
| `AGENT_POOL_SIZE` | 3 | Concurrent browser agents |

## Cost Estimates

Per-task costs (approximate):

- **Kimi 2.5 (Fireworks)**: ~$0.30-$1.50 depending on task complexity
- **Browser session**: ~$0.02/hour of cloud compute
- **Your markup**: 100-200% on top

Example pricing to user:
- Simple lookup: $1.00
- Complex multi-step: $3.00
- Subscription: $20/month for 10 tasks + $2 overage

## Limitations (PoC)

1. **No persistent browser sessions** - Each task starts fresh
2. **No proxy rotation** - Anti-bot detection may block
3. **No human-in-the-loop UI** - CAPTCHA handling is stubbed
4. **No push notifications** - iOS app would poll or use WebSocket
5. **Single-tenant** - No user authentication

## Next Steps for Production

1. **Add Redis** for persistence across restarts
2. **Implement proxy rotation** (Bright Data, Oxylabs)
3. **Add authentication** (Clerk, Auth0)
4. **Build iOS app** - SwiftUI chat + push notifications
5. **Add billing** - Stripe integration, usage tracking
6. **Monitoring** - LangSmith, Helicone for LLM observability
7. **Retry logic** - Exponential backoff, failure recovery

## File Structure

```
poc-agent/
├── agent/
│   ├── __init__.py
│   └── core.py          # WebAgent + AgentPool
├── api/
│   ├── __init__.py
│   └── main.py          # FastAPI endpoints
├── scheduler/
│   ├── __init__.py
│   └── queue.py         # Task queue (Redis/in-memory)
├── tests/
│   └── test_agent.py    # Unit tests
├── requirements.txt
└── README.md
```

## Resources

- [browser-use](https://github.com/browser-use/browser-use) - AI-native web agent framework
- [Fireworks Kimi 2.5](https://fireworks.ai/models/fireworks/kimi-k2p5) - Base model
- [Playwright](https://playwright.dev/) - Browser automation
