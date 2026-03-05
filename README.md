# Browser AI

Terminal-style web agent. Runs browser tasks. Monitors until done.

## Quick Start

```bash
# Install
cd poc-agent
source venv/bin/activate
pip install fastapi uvicorn browser-use langchain-fireworks

# Run
export OPENROUTER_API_KEY=sk-...
uvicorn api.main:app --reload

# Web UI
open static/index.html
```

## What It Does

- Accepts natural language tasks
- Executes immediately with browser-use + Kimi 2.5
- If unavailable, offers to monitor continuously
- Token-based pricing
- Terminal-style interface

## API

```bash
POST /chat/message
{"user_id": "u123", "message": "Book French Laundry"}
```

## Files

| File | Purpose |
|------|---------|
| `agent/core.py` | WebAgent with browser-use |
| `api/chat.py` | Conversational endpoint |
| `api/main.py` | FastAPI app |
| `static/index.html` | Terminal UI |
| `scheduler/persistent.py` | Long-running task scheduler |
| `models/user.py` | Token economy, credentials |

## Token Costs

| Action | Tokens |
|--------|--------|
| Check | 50 |
| Detailed check | 100 |
| Book | 200 |

300 free on signup. Buy more via Apple Pay.

## Example Flow

```
❯ Book French Laundry for 4
French Laundry: Fully booked. Waitlist available.
Monitor for cancellations? (y/n)
y
Monitoring. 30min checks. 7 days. ~168 tokens.
```
