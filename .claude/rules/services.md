# Glob: **/services/**,**/*service*,**/logic/**,**/core/**

## Service Files — What Belongs Here

Services contain BUSINESS LOGIC. The "what should happen" layer between routes and data.

### Allowed
- Business rules and logic ("if user is admin, allow X")
- Orchestrating multiple model/repository calls
- Data transformation and computation
- Calling external APIs
- Sending emails, notifications, events

### Not Allowed — Move It
- HTTP handling (request/response objects) → `routes/`
- Raw database queries → `repositories/`
- Data shape definitions → `models/`
- Config values → `config/`
- Generic utilities → `utils/`

### Pattern
```python
# services/user_service.py
def create_user(data: UserCreate, db: Session) -> UserResponse:
    if db.query(User).filter_by(email=data.email).first():
        raise ValueError("Email already registered")
    hashed = hash_password(data.password)
    user = User(email=data.email, name=data.name, password_hash=hashed)
    db.add(user)
    db.commit()
    return UserResponse.model_validate(user)
```

### Rules
- Services receive validated data (models), not raw request bodies
- Services return models, not HTTP responses
- One service file per domain: `services/user_service.py`
- Services can call other services, but avoid circular imports
- Keep functions focused — one action per function
