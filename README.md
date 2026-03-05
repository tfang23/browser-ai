# BrowserOps!

Autonomous web agent for long-horizon browser tasks. Executes commands, monitors availability, completes purchases.

## What It Does

Browser AI runs browser tasks that take time:

- **Restaurant reservations** — Monitors Tock/Resy until tables open, books immediately
- **Event tickets** — Waits in queue, purchases when sale starts
- **Limited drops** — Watches Nike/SNKRS inventory, checks out on restock
- **Price monitoring** — Tracks flights/hotels, alerts when price drops
- **Any web task** — General purpose browser automation

## Quick Start

```bash
# Clone
git clone https://github.com/tfang23/browser-ai.git
cd browser-ai

# Setup
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Configure
export OPENROUTER_API_KEY=sk-or-v1-...
export CREDENTIAL_MASTER_KEY=$(openssl rand -base64 32)

# Run
uvicorn api.main:app --reload

# Open UI
open static/index.html
```

## Architecture

```
User → Terminal UI → FastAPI → Agent Pool → browser-use + OpenRouter (Kimi 2.5)
                     ↓
              Task Queue (Redis/in-memory)
                     ↓
              Persistent Scheduler
```

## Core Components

### 1. WebAgent (`agent/core.py`)
Executes browser tasks using browser-use framework with Kimi 2.5 via OpenRouter.

```python
agent = WebAgent(openrouter_api_key="sk-...")
result = await agent.execute_task(
    task_id="task_123",
    prompt="Check French Laundry availability",
    context={"party_size": 4}
)
```

### 2. Chat API (`api/chat.py`)
Conversational interface that:
1. Executes tasks immediately
2. If unavailable → suggests monitoring
3. Collects frequency/duration preferences
4. Calculates token cost
5. Creates persistent monitoring task

### 3. Token Economy (`models/user.py`)
- 300 free tokens for new users
- Pay-per-use: ~$0.01 per token
- Packages: Starter ($4.99), Standard ($9.99), Power ($24.99)

### 4. Persistent Tasks (`scheduler/persistent.py`)
Long-running monitors that:
- Check at configured intervals (5min - 6hr)
- Run for specified duration (1-30 days)
- Auto-book when available
- Stop after expiration

## API Endpoints

### Chat
```bash
POST /chat/message
{
  "user_id": "user_abc",
  "message": "Book French Laundry for 4",
  "session_id": "sess_xyz"  // optional
}

Response:
{
  "session_id": "sess_xyz",
  "response": "French Laundry: Fully booked... Monitor? (y/n)",
  "state": "asking_monitor",
  "actions": [{"label": "Yes", "value": "y"}]
}
```

### Users
```bash
POST /users/                           # Create (gets 300 free tokens)
GET  /users/{id}                       # Profile + balance
POST /users/{id}/credentials           # Store encrypted credentials
POST /users/{id}/estimate-tokens     # Get cost before task
POST /users/{id}/purchase-tokens       # Buy with Apple receipt
```

### Tasks
```bash
GET  /users/{id}/tasks                 # List all tasks
GET  /users/{id}/frequency-options     # Get check frequencies with costs
```

## Token Costs

| Action | Tokens | ~USD | Description |
|--------|--------|------|-------------|
| Quick check | 50 | $0.50 | Is it available? |
| Detailed check | 100 | $1.00 | Browse multiple pages |
| Login flow | 150 | $1.50 | Authentication required |
| Full booking | 200 | $2.00 | Complete purchase flow |

### Example Estimates

**Restaurant monitoring** (30min checks, 7 days):
```
336 checks × 50 tokens = 16,800 tokens = ~$16.80
```

**Hot shoe drop** (5min checks, 24 hours):
```
288 checks × 50 tokens × 1.5 complexity = 21,600 tokens = ~$21.60
```

## Configuration

### Environment Variables

```bash
# Required
OPENROUTER_API_KEY=sk-or-v1-...        # LLM provider

# Security
CREDENTIAL_MASTER_KEY=...              # AES-256 key for user credentials

# Optional
REDIS_URL=redis://localhost:6379/0     # Task queue backend
AGENT_POOL_SIZE=3                      # Concurrent agents
PORT=8000                              # API server port
```

### Credential Encryption

User credentials (names, phones, payment info) are encrypted:
- Algorithm: AES-256-GCM
- Keys derived per-user from master secret
- Never logged or exposed in plaintext

## Frontend

Terminal-style interface in `static/index.html`:
- Dark theme with monospace font
- Real-time streaming responses
- Inline action buttons
- Token balance in header

## Deployment

### Docker

```dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
CMD ["uvicorn", "api.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### Fly.io

```bash
fly launch
fly secrets set OPENROUTER_API_KEY=sk-...
fly deploy
```

### iOS App

See `browser-ai-ios/` for SwiftUI app with:
- Apple Pay / StoreKit integration
- Push notifications
- Secure credential storage

## Development

```bash
# Run tests
pytest tests/

# Type checking
mypy agent/ api/ scheduler/

# Linting
ruff check .
```

## Limitations

- **Token costs are estimates** — Actual usage varies by task complexity
- **Anti-bot detection** — Some sites block automation (use residential proxies)
- **CAPTCHAs** — May require human-in-the-loop
- **No guarantees** — Sold out items may never restock

## Roadmap

- [ ] SMS notifications
- [ ] Slack/Discord integration
- [ ] Team/corporate accounts
- [ ] Chrome extension for local execution
- [ ] Vision API for CAPTCHA solving

## License

MIT — See LICENSE

## Support

Open an issue or email support@browserai.com
