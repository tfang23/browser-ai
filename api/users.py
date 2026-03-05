"""
API endpoints for user management, credentials, and token economy.
"""
from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any
from datetime import datetime

from models.user import (
    UserProfile, UserCredentials, CredentialType,
    CredentialEncryption, TokenEconomy, TokenPackage,
    NEW_USER_FREE_TOKENS
)


router = APIRouter(prefix="/users", tags=["users"])


# In-memory store for PoC (use database in production)
_users: Dict[str, UserProfile] = {}
_credentials: Dict[str, UserCredentials] = {}
_packages: List[TokenPackage] = TokenEconomy.DEFAULT_PACKAGES


# Pydantic models for API
class UserCreate(BaseModel):
    email: str
    phone: Optional[str] = None


class UserResponse(BaseModel):
    user_id: str
    email: str
    phone: Optional[str]
    token_balance: int
    created_at: str


class CredentialCreate(BaseModel):
    service_name: str                    # "tock", "nike", "ticketmaster"
    credential_type: str                 # "password", "payment", "personal"
    data: Dict[str, Any]                 # The actual credentials (will be encrypted)


class CredentialResponse(BaseModel):
    credential_id: str
    service_name: str
    credential_type: str
    created_at: str
    last_used_at: Optional[str]
    # Note: never return encrypted_data in API


class TokenEstimateRequest(BaseModel):
    task_type: str = Field(..., description="restaurant, ticket, retail_drop, flight, hotel")
    check_frequency_minutes: int = Field(default=30, ge=5, le=1440)
    max_duration_days: int = Field(default=7, ge=1, le=30)
    include_booking: bool = True


class TokenEstimateResponse(BaseModel):
    estimated_total_tokens: int
    num_checks: int
    breakdown: Dict[str, int]
    usd_estimate: float
    can_afford: bool  # Based on user's current balance
    recommended_packages: List[Dict]  # Packages that would cover this


class FrequencyOption(BaseModel):
    minutes: int
    label: str
    risk: str
    estimated_tokens: int
    estimated_usd: float


# Initialize encryption
_encryption: Optional[CredentialEncryption] = None

def get_encryption() -> CredentialEncryption:
    global _encryption
    if _encryption is None:
        _encryption = CredentialEncryption()
    return _encryption


@router.post("/", response_model=UserResponse)
async def create_user(user: UserCreate):
    """
    Create a new user with free starting tokens.
    """
    import uuid
    
    user_id = f"user_{uuid.uuid4().hex[:12]}"
    
    profile = UserProfile(
        user_id=user_id,
        email=user.email,
        phone=user.phone,
        token_balance=NEW_USER_FREE_TOKENS,
    )
    
    _users[user_id] = profile
    
    return UserResponse(
        user_id=profile.user_id,
        email=profile.email,
        phone=profile.phone,
        token_balance=profile.token_balance,
        created_at=profile.created_at
    )


@router.get("/{user_id}", response_model=UserResponse)
async def get_user(user_id: str):
    """Get user profile and token balance."""
    user = _users.get(user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    return UserResponse(
        user_id=user.user_id,
        email=user.email,
        phone=user.phone,
        token_balance=user.token_balance,
        created_at=user.created_at
    )


@router.post("/{user_id}/credentials", response_model=CredentialResponse)
async def store_credentials(user_id: str, cred: CredentialCreate):
    """
    Store encrypted credentials for a service.
    The data is encrypted before storage and never returned in plain text.
    """
    if user_id not in _users:
        raise HTTPException(status_code=404, detail="User not found")
    
    # Validate credential type
    try:
        CredentialType(cred.credential_type)
    except ValueError:
        raise HTTPException(
            status_code=400, 
            detail=f"Invalid credential type. Valid: {[t.value for t in CredentialType]}"
        )
    
    # Encrypt the credential data
    encryption = get_encryption()
    encrypted = encryption.encrypt(user_id, cred.data)
    
    import uuid
    cred_id = f"cred_{uuid.uuid4().hex[:12]}"
    
    credentials = UserCredentials(
        credential_id=cred_id,
        user_id=user_id,
        service_name=cred.service_name,
        credential_type=cred.credential_type,
        encrypted_data=encrypted,
        created_at=datetime.utcnow().isoformat(),
    )
    
    _credentials[cred_id] = credentials
    
    return CredentialResponse(
        credential_id=credentials.credential_id,
        service_name=credentials.service_name,
        credential_type=credentials.credential_type,
        created_at=credentials.created_at,
        last_used_at=credentials.last_used_at
    )


@router.get("/{user_id}/credentials", response_model=List[CredentialResponse])
async def list_credentials(user_id: str):
    """List all credentials for a user (metadata only, no secrets)."""
    if user_id not in _users:
        raise HTTPException(status_code=404, detail="User not found")
    
    user_creds = [
        c for c in _credentials.values() 
        if c.user_id == user_id and c.is_active
    ]
    
    return [
        CredentialResponse(
            credential_id=c.credential_id,
            service_name=c.service_name,
            credential_type=c.credential_type,
            created_at=c.created_at,
            last_used_at=c.last_used_at
        )
        for c in user_creds
    ]


@router.post("/{user_id}/estimate-tokens", response_model=TokenEstimateResponse)
async def estimate_tokens(user_id: str, request: TokenEstimateRequest):
    """
    Estimate token cost for a task before creating it.
    Also shows if user can afford and what packages to buy.
    """
    if user_id not in _users:
        raise HTTPException(status_code=404, detail="User not found")
    
    user = _users[user_id]
    
    estimate = TokenEconomy.estimate_task_cost(
        task_type=request.task_type,
        check_frequency_minutes=request.check_frequency_minutes,
        max_duration_days=request.max_duration_days,
        include_booking=request.include_booking
    )
    
    # Find packages that would cover this
    needed_tokens = estimate["estimated_total_tokens"]
    recommended = [
        {
            "package_id": p.package_id,
            "name": p.name,
            "total_tokens": p.total_tokens,
            "price_usd": p.price_usd,
            "covers_task": p.total_tokens >= needed_tokens,
        }
        for p in _packages
    ]
    
    return TokenEstimateResponse(
        estimated_total_tokens=estimate["estimated_total_tokens"],
        num_checks=estimate["num_checks"],
        breakdown=estimate["breakdown"],
        usd_estimate=estimate["usd_estimate"],
        can_afford=user.token_balance >= estimate["estimated_total_tokens"],
        recommended_packages=recommended
    )


@router.get("/{user_id}/frequency-options")
async def get_frequency_options(user_id: str, task_type: str):
    """
    Get recommended check frequencies with token estimates.
    Helps users pick the right balance of speed vs cost.
    """
    if user_id not in _users:
        raise HTTPException(status_code=404, detail="User not found")
    
    options = TokenEconomy.get_recommended_frequency(task_type)
    
    return [FrequencyOption(**opt) for opt in options]


@router.get("/packages", response_model=List[Dict])
async def get_token_packages():
    """Get available token packages for purchase."""
    return [
        {
            "package_id": p.package_id,
            "name": p.name,
            "token_amount": p.token_amount,
            "bonus_tokens": p.bonus_tokens,
            "total_tokens": p.total_tokens,
            "price_usd": p.price_usd,
            "effective_price_per_token": round(p.effective_price_per_token, 4),
        }
        for p in _packages
    ]


@router.post("/{user_id}/purchase-tokens")
async def purchase_tokens(user_id: str, package_id: str):
    """
    Purchase a token package.
    In production: Integrate with Stripe, verify payment, then credit tokens.
    """
    if user_id not in _users:
        raise HTTPException(status_code=404, detail="User not found")
    
    package = next((p for p in _packages if p.package_id == package_id), None)
    if not package:
        raise HTTPException(status_code=404, detail="Package not found")
    
    user = _users[user_id]
    
    # In production: verify Stripe payment here
    # For PoC: just add tokens
    user.token_balance += package.total_tokens
    
    return {
        "user_id": user_id,
        "package_id": package_id,
        "tokens_added": package.total_tokens,
        "new_balance": user.token_balance,
        "status": "completed"
    }
