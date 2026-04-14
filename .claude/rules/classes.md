# Glob: **/*.py,**/*.go

## Classes and Structs — Placement Rules

Classes have a home. Don't scatter them.

### Where Classes Belong

| Class type | Location | Example |
|:-----------|:---------|:--------|
| Data shapes (fields only) | `models/` | `User`, `TeamCreate`, `OrderResponse` |
| Business logic objects | `services/` | `PaymentProcessor`, `NotificationSender` |
| Database access objects | `repositories/` | `UserRepository`, `OrderRepository` |
| Middleware / decorators | `middleware/` | `AuthMiddleware`, `RateLimiter` |
| Pure utility classes | `utils/` | `TokenGenerator`, `SlugBuilder` |
| App config containers | `config/` | `AppSettings`, `DatabaseConfig` |

### Rules
- One class per file when the class is >50 lines
- Related small classes can share a file (e.g. `UserCreate` + `UserResponse` in `models/user.py`)
- Never define a class inside a route handler
- Never define a class inside a function
- Inheritance: max 2 levels deep. Prefer composition over inheritance
- If a class has no methods, make it a dataclass / Pydantic model / struct
- If a class has no state, make its methods standalone functions in `utils/`
