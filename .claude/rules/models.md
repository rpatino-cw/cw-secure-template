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

### Rules
- One model file per domain entity: `models/user.py`, `models/team.py`
- Separate input models from output models (UserCreate vs UserResponse)
- Never import from `routes/` — models are dependency-free
- Passwords: never a field on response models. Hash on create, never store plain text
