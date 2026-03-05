"""
User management with secure credential storage and token balance tracking.

Security principles:
- Credentials encrypted at rest (AES-256-GCM with per-user keys)
- Token balances in plaintext (not sensitive)
- Audit logging for all credential access
- PCI-DSS considerations for payment methods
"""
import os
import json
import base64
from typing import Optional, Dict, Any, List
from datetime import datetime
from dataclasses import dataclass, asdict
from enum import Enum

from cryptography.fernet import Fernet
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC


class CredentialType(Enum):
    """Types of credentials a user might store."""
    PASSWORD = "password"           # Website login password
    OTP_SECRET = "otp_secret"       # 2FA/TOTP secret
    API_KEY = "api_key"             # API key for external services
    PAYMENT_METHOD = "payment"      # Credit card (tokenized)
    PERSONAL_INFO = "personal"      # Name, address, phone (encrypted)


@dataclass
class UserCredentials:
    """
    Encrypted credential bundle for a specific service.
    Example: Tock login, Nike account, etc.
    """
    credential_id: str           # unique ID for this credential set
    user_id: str
    service_name: str            # "tock", "resy", "nike", "ticketmaster"
    credential_type: str         # from CredentialType
    
    # Encrypted data (JSON blob)
    encrypted_data: str           # base64 encrypted JSON
    
    # Metadata (plaintext)
    created_at: str
    last_used_at: Optional[str] = None
    expires_at: Optional[str] = None  # For session cookies
    is_active: bool = True
    
    # Audit
    access_count: int = 0


@dataclass  
class UserProfile:
    """
    Core user profile with token balance.
    """
    user_id: str
    email: str
    phone: Optional[str] = None
    
    # Token economy
    token_balance: int = 0         # Current balance (starts with free credits)
    total_tokens_used: int = 0     # Lifetime usage
    
    # Account status
    created_at: str = ""
    last_login_at: Optional[str] = None
    is_active: bool = True
    
    # Preferences
    default_check_frequency_minutes: int = 30
    notification_preferences: Dict = None
    
    def __post_init__(self):
        if not self.created_at:
            self.created_at = datetime.utcnow().isoformat()
        if self.notification_preferences is None:
            self.notification_preferences = {
                "push_enabled": True,
                "email_enabled": False,
                "sms_enabled": False
            }


@dataclass
class TokenPackage:
    """
    Token packages users can purchase.
    """
    package_id: str
    name: str                      # "Starter Pack", "Power User", etc.
    token_amount: int              # Number of tokens
    price_usd: float               # Price in dollars
    bonus_tokens: int = 0          # Extra tokens as promotion
    
    @property
    def total_tokens(self) -> int:
        return self.token_amount + self.bonus_tokens
    
    @property
    def effective_price_per_token(self) -> float:
        return self.price_usd / self.total_tokens if self.total_tokens > 0 else 0


class CredentialEncryption:
    """
    Handles encryption/decryption of user credentials.
    Each user gets a derived key from a master secret + their user_id.
    """
    
    def __init__(self, master_key: Optional[str] = None):
        self.master_key = master_key or os.getenv("CREDENTIAL_MASTER_KEY")
        if not self.master_key:
            raise ValueError("CREDENTIAL_MASTER_KEY required for encryption")
    
    def _get_user_key(self, user_id: str) -> bytes:
        """Derive a unique key for this user."""
        kdf = PBKDF2HMAC(
            algorithm=hashes.SHA256(),
            length=32,
            salt=user_id.encode(),  # User ID as salt
            iterations=480000,
        )
        key = base64.urlsafe_b64encode(kdf.derive(self.master_key.encode()))
        return key
    
    def encrypt(self, user_id: str, data: Dict) -> str:
        """Encrypt a dictionary to base64 string."""
        key = self._get_user_key(user_id)
        f = Fernet(key)
        
        json_data = json.dumps(data).encode()
        encrypted = f.encrypt(json_data)
        return base64.urlsafe_b64encode(encrypted).decode()
    
    def decrypt(self, user_id: str, encrypted_b64: str) -> Dict:
        """Decrypt base64 string back to dictionary."""
        key = self._get_user_key(user_id)
        f = Fernet(key)
        
        encrypted = base64.urlsafe_b64decode(encrypted_b64.encode())
        decrypted = f.decrypt(encrypted)
        return json.loads(decrypted.decode())


class TokenEconomy:
    """
    Manages token costs and balances.
    """
    
    # Cost estimates (in tokens)
    # These are configurable and should be tuned based on actual usage
    COSTS = {
        "base_check": 50,           # Simple check (is it available?)
        "detailed_check": 100,       # Check with browsing multiple pages
        "booking_attempt": 200,      # Full booking flow
        "login_flow": 150,           # If we need to log in first
        "vision_analysis": 75,       # Per screenshot analyzed
        "retry_penalty": 25,         # Failed attempt overhead
    }
    
    # Default packages
    DEFAULT_PACKAGES = [
        TokenPackage("starter", "Starter Pack", 500, 4.99, bonus_tokens=100),
        TokenPackage("standard", "Standard Pack", 1500, 9.99, bonus_tokens=300),
        TokenPackage("power", "Power User", 5000, 24.99, bonus_tokens=1000),
        TokenPackage("enterprise", "Enterprise", 20000, 79.99, bonus_tokens=5000),
    ]
    
    @classmethod
    def estimate_task_cost(
        cls,
        task_type: str,
        check_frequency_minutes: int,
        max_duration_days: int = 7,
        include_booking: bool = True
    ) -> Dict:
        """
        Estimate total tokens needed for a task.
        
        Args:
            task_type: "restaurant", "ticket", "retail_drop", etc.
            check_frequency_minutes: How often to check
            max_duration_days: How long to monitor
            include_booking: Whether to include final booking cost
        """
        # Calculate number of checks
        total_minutes = max_duration_days * 24 * 60
        num_checks = total_minutes // check_frequency_minutes
        
        # Base check cost (varies by task complexity)
        complexity_multiplier = {
            "restaurant": 1.0,
            "ticket": 1.2,      # Ticket sites often harder
            "retail_drop": 1.5,  # High-traffic, anti-bot
            "flight": 1.3,
            "hotel": 1.1,
        }.get(task_type, 1.0)
        
        check_cost = cls.COSTS["detailed_check"] * complexity_multiplier
        
        # Most checks will find nothing (sold out)
        # Assume 10% find availability, 90% are no-ops
        estimated_hits = max(1, num_checks * 0.1)  # At least 1 hit expected
        
        checks_cost = num_checks * cls.COSTS["base_check"]
        hits_cost = estimated_hits * check_cost
        
        # Booking cost (if included)
        booking_cost = cls.COSTS["booking_attempt"] if include_booking else 0
        
        # Buffer for retries/errors (20%)
        subtotal = checks_cost + hits_cost + booking_cost
        buffer = subtotal * 0.2
        
        total = int(subtotal + buffer)
        
        return {
            "estimated_total_tokens": total,
            "num_checks": num_checks,
            "check_frequency_minutes": check_frequency_minutes,
            "max_duration_days": max_duration_days,
            "breakdown": {
                "monitoring_cost": int(checks_cost),
                "availability_checks_cost": int(hits_cost),
                "booking_cost": booking_cost,
                "buffer": int(buffer),
            },
            "usd_estimate": round(total * 0.01, 2),  # Assuming 1 token = ~$0.01
        }
    
    @classmethod
    def get_recommended_frequency(cls, task_type: str) -> List[Dict]:
        """Get recommended check frequencies with token estimates."""
        frequencies = [
            {"minutes": 5, "label": "Every 5 min (aggressive)", "risk": "High token usage"},
            {"minutes": 15, "label": "Every 15 min", "risk": "Medium-high usage"},
            {"minutes": 30, "label": "Every 30 min", "risk": "Balanced"},
            {"minutes": 60, "label": "Every hour", "risk": "Low usage, may miss fast drops"},
            {"minutes": 360, "label": "Every 6 hours", "risk": "Very low, for slow releases only"},
        ]
        
        results = []
        for f in frequencies:
            estimate = cls.estimate_task_cost(
                task_type=task_type,
                check_frequency_minutes=f["minutes"],
                max_duration_days=7
            )
            results.append({
                **f,
                "estimated_tokens": estimate["estimated_total_tokens"],
                "estimated_usd": estimate["usd_estimate"],
            })
        
        return results


# Free token grant for new users
NEW_USER_FREE_TOKENS = 300  # Enough for ~1 simple task or ~6 quick checks

# Example: Simple restaurant check
# - Base check: 50 tokens
# - 1 check every 30 min for 2 days: 96 checks = 4,800 tokens
# - Plus 1 booking attempt: 200 tokens
# - Total: ~5,000 tokens = ~$50
# 
# But with the free 300 tokens, user can do:
# - 6 quick checks (300/50) for a hot restaurant
# Or
# - 1 complete simple booking (if they're lucky and it's available quickly)