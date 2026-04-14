# Glob: **/models/**,**/schemas/**,**/*model*,**/*schema*,**/*types*

## Data Models — What Belongs Here

Models define the SHAPE of data. Validation, types, schemas, database table definitions.

### Allowed
- Pydantic models / Go structs for request/response shapes
- Database table definitions (SQLAlchemy, GORM, raw DDL)
- Validation rules (field constraints, custom validators)
- Type aliases and enums
- Relationship definitions between models

### Not Allowed — Move It
- Query logic (SELECT, INSERT) → `repositories/` or `services/`
- Business rules ("if admin then...") → `services/`
- HTTP-specific code (status codes, headers) → `routes/`
- Environment variables or config → `config/`

### Pattern
```python
# models/user.py
class UserCreate(BaseModel):
    email: EmailStr
    name: str = Field(min_length=1, max_length=100)

class UserResponse(BaseModel):
    id: int
    email: str
    name: str
    created_at: datetime
```

### Dependency Direction
```
models/ imports from → nothing (or stdlib only)
models/ NEVER imports from → routes/, services/, repositories/, db/
```

Models are the BOTTOM layer. They depend on nothing. Everything else depends on them.

### Violations to Block
- Model file importing from `routes/`, `services/`, or `handlers/` → circular dependency, refuse
- Database query logic inside a model definition → move to `repositories/`
- HTTP-specific code (status codes, request objects) in models → move to `routes/`
- Model without validation constraints → add Field() constraints or struct tags
- Single `models.py` file with 5+ models → split into one file per entity
- Plain text password field on any model → must be `password_hash`, never `password`

### Rules
- One model file per domain entity: `models/user.py`, `models/team.py`
- Separate input models from output models (UserCreate vs UserResponse)
- Never import from `routes/` — models are dependency-free
- Passwords: never a field on response models. Hash on create, never store plain text
