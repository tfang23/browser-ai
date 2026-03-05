# Browser Tasks

Technical deep-dive into the browser automation layer of Browser AI.

## Overview

The `agent/` module provides a thin wrapper around [browser-use](https://github.com/browser-use/browser-use) that adds:

- **Async agent pool** for concurrent task execution
- **Kimi 2.5 integration** via OpenRouter
- **Cost tracking** per task execution
- **Error handling** with automatic retries

## How It Works

```
User Request
    ↓
WebAgent.execute_task()
    ↓
browser-use Agent
    ↓
OpenRouter API (Kimi 2.5)
    ↓
Playwright Browser
    ↓
Target Website
```

## Core Classes

### WebAgent

Main interface for executing browser tasks.

```python
from agent.core import WebAgent

agent = WebAgent(openrouter_api_key="sk-or-v1-...")

result = await agent.execute_task(
    task_id="task_123",
    prompt="Check if iPhone 16 Pro is in stock on apple.com",
    context={"zip_code": "94102"},
    max_steps=25
)
```

**Parameters:**
- `task_id`: Unique identifier for tracking
- `prompt`: Natural language instruction
- `context`: Key-value pairs for personalization
- `max_steps`: Hard limit on browser actions (prevents runaway)

**Returns:**
```python
{
    "task_id": "task_123",
    "status": "completed",
    "result": "iPhone 16 Pro: Available...",
    "success": True,
    "duration_seconds": 12.4,
    "timestamp": "2026-03-05T21:30:00"
}
```

### AgentPool

Manages concurrent browser sessions.

```python
from agent.core import AgentPool

pool = AgentPool(
    pool_size=3,  # Max 3 concurrent tasks
    openrouter_api_key="sk-..."
)

# Execute with automatic queueing
result = await pool.execute(task_id, prompt, context)
```

Pool uses `asyncio.Semaphore` to prevent overwhelming the API.

## Browser Automation Flow

### 1. Task Interpretation

Kimi 2.5 parses the natural language prompt:

```
Prompt: "Check French Laundry availability for 4 people next Friday"

LLM generates:
1. Navigate to tock.com/french-laundry
2. Select party size: 4
3. Select date: next Friday
4. Check available times
5. Return results
```

### 2. Browser Actions

browser-use executes via Playwright:

```python
# Internal browser-use flow
agent = Agent(
    task=prompt,
    llm=ChatOpenRouter(model="moonshotai/kimi-k2.5"),
    use_vision=True  # Screenshots for context
)

# Each step:
# 1. Screenshot page
# 2. Send to LLM with current state
# 3. LLM returns: click(x,y), type(text), scroll, etc.
# 4. Execute action
# 5. Repeat until done
```

### 3. Site-Specific Challenges

| Site | Challenge | Mitigation |
|------|-----------|------------|
| Tock | Rate limiting | 30s+ delays between checks |
| Ticketmaster | Queue system | Early session, keep alive |
| Nike | Anti-bot | Residential proxies |
| Airlines | Dynamic pricing | Multiple checks, compare |

## Common Task Patterns

### Restaurant Reservation

```python
prompt = """
Book a table at {restaurant} on {date} for {party_size} people.
Name: {name}
Phone: {phone}
If no tables, join waitlist.
"""
```

**Typical flow:**
1. Navigate to reservation site
2. Select date/party size
3. Scan available times
4. Select earliest preferred slot
5. Fill contact info
6. Complete booking

**Failure modes:**
- Fully booked → suggest monitoring
- Booking requires deposit → pause for human
- Phone verification needed → SMS to user

### Ticket Purchase

```python
prompt = """
Buy {quantity} tickets for {event} on {date}.
Max price per ticket: ${max_price}
Section preference: {sections}
Use presale code: {code}
"""
```

**Typical flow:**
1. Join queue early (30+ min before)
2. Wait for queue position
3. Select tickets matching criteria
4. Bypass upsells (insurance, parking)
5. Checkout with stored payment

**Failure modes:**
- Queue timeout → restart
- Tickets sell out → monitoring mode
- Price above max → wait for drops

### Inventory Monitoring

```python
prompt = """
Check if {product} is in stock at {retailer}.
Size: {size}
Color: {color}
If out of stock, note restock patterns.
"""
```

**Typical flow:**
1. Check product page
2. Verify size/color availability
3. Add to cart if available
4. If unavailable, note "Notify Me" option

**Success patterns:**
- "Add to Cart" button active → success
- "Out of Stock" → continue monitoring
- "Coming Soon" with date → schedule check

## Cost Model

Each browser action consumes tokens via LLM calls:

```
Per-step cost breakdown:
- Screenshot → input tokens (base64 image)
- LLM inference → ~2-5K tokens
- Action execution → minimal

Typical task (10 steps):
- Input: 10K tokens @ $0.003/1K = $0.03
- Output: 5K tokens @ $0.015/1K = $0.075
- Total: ~$0.10 per task attempt
```

Monitoring adds up:
```
Every 30 min for 7 days = 336 checks
336 × $0.10 = $33.60 in LLM costs

We charge: 336 × 50 tokens = 16,800 tokens = ~$16.80
(Margin covers infrastructure + profit)
```

## Error Handling

### Retries

```python
max_failures = 3

# Retry on:
- Network timeout
- Page load failure
- LLM rate limit

# Don't retry:
- Task completed successfully
- Site completely down
- Authentication failure (needs human)
```

### Graceful Degradation

| Error | Response |
|-------|----------|
| CAPTCHA detected | "Need your help — solve this captcha" |
| 2FA required | "Enter code sent to your phone" |
| Site changed | "Site updated — adjusting approach" |
| Sold out | "Unavailable — monitoring for restock?" |

## Security Considerations

### Credential Handling

```python
# User context is encrypted
context = {
    "name": encrypt("John Doe"),
    "phone": encrypt("+1-555-1234"),
    "cc_last4": encrypt("4242")
}

# Only decrypted in agent.execute_task
# Logs never show plaintext
```

### Browser Isolation

Each task gets:
- Fresh browser context (no shared cookies)
- Isolated IP (if using proxy rotation)
- Clean session storage
- No access to other tasks' data

### Anti-Detection Measures

```python
# Playwright stealth options
browser = await playwright.chromium.launch(
    headless=True,
    args=[
        '--disable-blink-features=AutomationControlled',
        '--disable-web-security',
        '--disable-features=IsolateOrigins,site-per-process'
    ]
)
```

## Performance Optimization

### Caching

- Page content cached for 60s
- LLM responses cached for identical states
- Session cookies reused for same site (within task)

### Parallelization

```python
# Multiple users, different sites
async with pool:
    # Task 1: Nike (user A)
    # Task 2: Tock (user B)  
    # Task 3: United (user C)
    # All execute concurrently
```

### Lazy Loading

Don't load heavy elements:
```python
# Skip images, videos, fonts
await page.route("**/*.{png,jpg,jpeg,gif,svg}", lambda route: route.abort())
```

## Testing

### Mock Mode

```python
# For unit tests
class MockWebAgent:
    async def execute_task(self, **kwargs):
        return {
            "success": True,
            "result": "Mock result",
            "mock": True
        }
```

### Staging Environment

Use test sites:
- `https://resy.com` → staging.resy.com
- Real inventory but fake bookings

### Regression Tests

```python
@pytest.mark.asyncio
async def test_french_laundry_flow():
    result = await agent.execute_task(
        prompt="Check French Laundry availability",
        context={"party_size": 2}
    )
    assert "Tock" in result["result"]
    assert result["success"] or "sold out" in result["result"].lower()
```

## Debugging

### Verbose Logging

```python
import logging
logging.basicConfig(level=logging.DEBUG)

# Shows:
# - Every browser action
# - LLM prompts/responses
# - Screenshot saves
# - Timing breakdowns
```

### Local Browser View

```python
# Run non-headless to watch
agent = Agent(
    task=prompt,
    llm=llm,
    browser_context=BrowserContext(
        headless=False,  # Visible browser
        slow_mo=1000     # 1s delay per action
    )
)
```

### Replay

```python
# Save execution trace
trace_path = f"traces/{task_id}.json"

# Replay later for debugging
with open(trace_path) as f:
    trace = json.load(f)
    for step in trace["steps"]:
        print(f"{step['action']}: {step['result']}")
```

## Future Improvements

- [ ] **Vision-only mode** — Skip DOM parsing, use GPT-4V on screenshots only
- [ ] **Learning** — Remember successful patterns per site
- [ ] **Human-in-the-loop UI** — Real-time approval for expensive actions
- [ ] **Mobile optimization** — Run agents on mobile-optimized sites
- [ ] **Local execution** — Chrome extension for user-local automation

## References

- [browser-use docs](https://docs.browser-use.com)
- [Kimi 2.5 on OpenRouter](https://openrouter.ai/moonshotai/kimi-k2.5)
- [Playwright best practices](https://playwright.dev/docs/best-practices)
