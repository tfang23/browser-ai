# POC Agent - AI Web Automation

A proof-of-concept backend for autonomous web agents using **browser-use** and **Kimi 2.5** on Fireworks.

## Architecture

```
iOS App (Thin Client)
    ↓ HTTP/WebSocket
FastAPI Server
    ↓
User Management (Token balances, encrypted credentials)
    ↓
Persistent Task Scheduler (Monitoring & booking)
    ↓
Task Queue (Redis or in-memory)
    ↓
Agent Pool (3 concurrent workers)
    ↓
browser-use + Playwright + OpenRouter (Kimi 2.5)
```

## Key Features

### Token Economy
- **300 free tokens** for new users (enough for ~1 simple task or ~6 checks)
- **Buy token packages** when depleted
- **Cost estimation** before starting any task
- **Variable check frequency** — user chooses speed vs cost tradeoff

### Secure Credential Storage
- **AES-256-GCM encryption** for all user credentials
- **Per-user derived keys** — no master key exposure
- **Service-specific credentials** — Tock, Nike, Ticketmaster, etc.
- **Audit logging** for all credential access

### General-Purpose Tasks
| Task Type | Example | Check Frequency |
|-----------|---------|-----------------|
| Restaurant | "Book French Laundry" | Every 30 min |
| Tickets | "Get Taylor Swift tickets" | Every 5 min |
| Retail Drop | "Buy limited Nike Dunks" | Every 1 min |
| Flight | "Book JFK-Tokyo when price drops" | Every hour |
| Hotel | "Reserve Aman Tokyo" | Every 6 hours |

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
OPENROUTER_API_KEY=your_openrouter_api_key_here
CREDENTIAL_MASTER_KEY=your_encryption_key_here  # For credential encryption
REDIS_URL=redis://localhost:6379/0  # Optional - falls back to in-memory
AGENT_POOL_SIZE=3
```

Get your OpenRouter API key at [openrouter.ai/keys](https://openrouter.ai/keys)

Generate a random credential master key: `openssl rand -base64 32`

### 3. Run the API Server

```bash
cd poc-agent
uvicorn api.main:app --reload --host 0.0.0.0 --port 8000
```

### 4. Test the API

```bash
export OPENROUTER_API_KEY=your_key_here

# Health check
curl http://localhost:8000/health

# Create a user (gets 300 free tokens)
curl -X POST http://localhost:8000/users/ \
  -H "Content-Type: application/json" \
  -d '{"email": "user@example.com"}'

# Estimate token cost for a restaurant booking
curl -X POST http://localhost:8000/users/user_xxx/estimate-tokens \
  -H "Content-Type: application/json" \
  -d '{
    "task_type": "restaurant",
    "check_frequency_minutes": 30,
    "max_duration_days": 7
  }'

# Create a simple task
curl -X POST http://localhost:8000/tasks \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "Find the price of iPhone 16 Pro on apple.com",
    "context": {"user_name": "Test User"}
  }'

# Check task status
curl http://localhost:8000/tasks/task_abc123
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

## Token Economy

### Free Starting Balance
Every new user gets **300 tokens** — enough for:
- ~6 availability checks, OR
- ~1 complete booking (if available quickly)

### Token Costs
| Action | Tokens | ~USD |
|--------|--------|------|
| Quick check (sold out?) | 50 | $0.50 |
| Detailed check (browse & analyze) | 100 | $1.00 |
| Login flow | 150 | $1.50 |
| Full booking attempt | 200 | $2.00 |
| Vision analysis (screenshot) | 75 | $0.75 |

### Example Estimates

**Restaurant reservation** (30 min checks, 7 days):
- 336 checks × 50 tokens = 16,800 tokens
- ~1 booking attempt = 200 tokens
- **Total: ~17,000 tokens = ~$17**

**Limited shoe drop** (1 min checks, 24 hours):
- 1,440 checks × 50 tokens = 72,000 tokens
- High anti-bot complexity × 1.5 = 108,000 tokens
- ~3 booking attempts = 600 tokens
- **Total: ~108,600 tokens = ~$108**

### Token Packages
| Package | Tokens | Price | Bonus | Total |
|---------|--------|-------|-------|-------|
| Starter | 500 | $4.99 | 100 | 600 |
| Standard | 1,500 | $9.99 | 300 | 1,800 |
| Power | 5,000 | $24.99 | 1,000 | 6,000 |
| Enterprise | 20,000 | $79.99 | 5,000 | 25,000 |

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
- [OpenRouter](https://openrouter.ai/) - Unified API for LLMs (including Kimi 2.5 via Fireworks)
- [Kimi 2.5 on OpenRouter](https://openrouter.ai/moonshotai/kimi-k2.5) - Base model
- [Playwright](https://playwright.dev/) - Browser automation
