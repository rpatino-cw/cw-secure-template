# Multi-stage build — CW Chainguard base for non-root, minimal attack surface
FROM cgr.dev/coreweave/python:3.13-dev AS builder
WORKDIR /app
COPY pyproject.toml ./
RUN pip install --no-cache-dir -e .

FROM cgr.dev/coreweave/python:3.13
WORKDIR /app
COPY --from=builder /app /app
COPY src ./src
USER nonroot
EXPOSE 8080
CMD ["uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8080"]
