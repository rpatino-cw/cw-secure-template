"""Alembic migration environment — async-ready with target_metadata from models.

Reads DATABASE_URL from the environment so credentials never appear in config files.
Supports both synchronous and asynchronous migration execution.
"""

import asyncio
import os
from logging.config import fileConfig

from alembic import context
from sqlalchemy import pool
from sqlalchemy.engine import Connection
from sqlalchemy.ext.asyncio import async_engine_from_config

# Import your models' metadata here. When you create SQLAlchemy models,
# import their Base.metadata so Alembic can auto-detect schema changes.
#
# Example:
#   from src.models import Base
#   target_metadata = Base.metadata
#
# Until you have models, use None (migrations must be written manually).
target_metadata = None

# Alembic Config object — provides access to values in alembic.ini.
config = context.config

# Set up Python logging from the ini file.
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

# Override sqlalchemy.url with DATABASE_URL from environment.
# This is the critical security pattern — credentials stay in .env, not in code.
database_url = os.environ.get("DATABASE_URL", "")
if database_url:
    config.set_main_option("sqlalchemy.url", database_url)


def run_migrations_offline() -> None:
    """Run migrations in 'offline' mode — generates SQL without connecting.

    Useful for generating migration scripts to review before applying,
    or for environments where direct DB access is restricted.
    """
    url = config.get_main_option("sqlalchemy.url")
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )

    with context.begin_transaction():
        context.run_migrations()


def do_run_migrations(connection: Connection) -> None:
    """Execute migrations against an active database connection."""
    context.configure(connection=connection, target_metadata=target_metadata)
    with context.begin_transaction():
        context.run_migrations()


async def run_async_migrations() -> None:
    """Run migrations using an async engine (for asyncpg, aiosqlite, etc.)."""
    connectable = async_engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )

    async with connectable.connect() as connection:
        await connection.run_sync(do_run_migrations)

    await connectable.dispose()


def run_migrations_online() -> None:
    """Run migrations in 'online' mode — connects to the database.

    Uses async engine if the URL scheme supports it (asyncpg, aiosqlite).
    Falls back to synchronous execution otherwise.
    """
    url = config.get_main_option("sqlalchemy.url", "")
    if url and ("+asyncpg" in url or "+aiosqlite" in url):
        asyncio.run(run_async_migrations())
    else:
        # Synchronous fallback for psycopg2, sqlite, etc.
        from sqlalchemy import engine_from_config

        connectable = engine_from_config(
            config.get_section(config.config_ini_section, {}),
            prefix="sqlalchemy.",
            poolclass=pool.NullPool,
        )

        with connectable.connect() as connection:
            do_run_migrations(connection)


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
