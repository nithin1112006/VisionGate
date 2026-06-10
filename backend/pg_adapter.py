"""
PostgreSQL adapter: drop-in replacement for sqlite3.
Provides a global cursor that auto-manages connections per-thread.
"""

import os
import threading
from dotenv import load_dotenv
import psycopg2
from psycopg2 import pool
from psycopg2.extras import RealDictCursor

# Load .env file if it exists
load_dotenv(os.path.join(os.path.dirname(__file__), ".env"))


class _ThreadLocalCursor:
    """
    A thread-local cursor that wraps psycopg2 connections.
    Mimics sqlite3 cursor API: execute(sql, params), fetchone(), fetchall().
    Uses ? placeholders (auto-converted to %s).
    """

    def __init__(self):
        self._local = threading.local()
        self._pool = None
        self._init_pool()

    def _init_pool(self):
        self._pool = pool.ThreadedConnectionPool(
            minconn=5,
            maxconn=30,
            host=os.environ.get("PG_HOST", "localhost"),
            port=int(os.environ.get("PG_PORT", "5432")),
            dbname=os.environ.get("PG_DB", "attenda"),
            user=os.environ.get("PG_USER", "attenda"),
            password=os.environ.get("PG_PASSWORD", "attenda_password"),
        )

    def _get_conn(self):
        if (
            not hasattr(self._local, "conn")
            or self._local.conn is None
            or self._local.conn.closed
        ):
            self._local.conn = self._pool.getconn()
            self._local.conn.autocommit = True
            self._local.cursor = self._local.conn.cursor(cursor_factory=RealDictCursor)
        return self._local.conn, self._local.cursor

    def execute(self, sql, params=None):
        conn, cur = self._get_conn()
        sql = sql.replace("?", "%s")
        if params is not None:
            cur.execute(sql, params)
        else:
            cur.execute(sql)

        # Capture generated ID for INSERT queries
        self._local.lastrowid = None
        if sql.strip().upper().startswith("INSERT"):
            try:
                # Use a separate cursor on the same connection to avoid altering main cursor state
                with conn.cursor() as temp_cur:
                    temp_cur.execute("SELECT LASTVAL()")
                    row = temp_cur.fetchone()
                    if row:
                        self._local.lastrowid = row[0]
            except Exception:
                pass

    def fetchone(self):
        _, cur = self._get_conn()
        row = cur.fetchone()
        if row is None:
            return None
        return tuple(row.values())

    def fetchall(self):
        _, cur = self._get_conn()
        rows = cur.fetchall()
        return [tuple(r.values()) for r in rows]

    def fetchval(self, column=0):
        _, cur = self._get_conn()
        row = cur.fetchone()
        if row is None:
            return None
        keys = list(row.keys())
        return row[keys[column]]

    @property
    def lastrowid(self):
        return getattr(self._local, "lastrowid", None)

    def commit(self):
        pass  # autocommit=True

    def close(self):
        if hasattr(self._local, "conn") and self._local.conn:
            try:
                self._pool.putconn(self._local.conn)
            except Exception:
                pass
            self._local.conn = None
            self._local.cursor = None

    def closeall(self):
        self._pool.closeall()


# Global cursor instance - drop-in replacement for sqlite3 cursor
cursor = _ThreadLocalCursor()

# Compatibility alias
conn = cursor
