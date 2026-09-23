#!/usr/bin/env python3
"""
VisionGate - Authentication & Credential Diagnostics & Repair Utility
Audits PostgreSQL database on the Linux host (ports 5434 / 5432), inspects existing accounts,
detects password hash types (bcrypt, plaintext, sha256, md5), fixes missing schema columns,
and provides instant credential resets and login simulation.
"""

import sys
import os
import argparse
import hashlib
import bcrypt
import psycopg2
from psycopg2.extras import RealDictCursor

# Auto-detect ports and credentials
def get_db_connection():
    ports = [
        int(os.environ.get("PG_PORT", 0)) if os.environ.get("PG_PORT") else None,
        5434,
        5432,
    ]
    ports = [p for p in ports if p is not None]

    db_name = os.environ.get("PG_DB", "attenda")
    db_user = os.environ.get("PG_USER", "attenda")
    db_pass = os.environ.get("PG_PASSWORD", "attenda_password")
    db_host = os.environ.get("PG_HOST", "127.0.0.1")

    for port in ports:
        try:
            conn = psycopg2.connect(
                host=db_host,
                port=port,
                dbname=db_name,
                user=db_user,
                password=db_pass,
                connect_timeout=3,
            )
            conn.autocommit = True
            return conn, port
        except Exception:
            # Fallback to postgres user
            try:
                conn = psycopg2.connect(
                    host=db_host,
                    port=port,
                    dbname=db_name,
                    user="postgres",
                    connect_timeout=3,
                )
                conn.autocommit = True
                return conn, port
            except Exception:
                continue

    return None, None


def ensure_schema_columns(conn):
    """Ensure all required columns for authentication & profile exist."""
    ddl_statements = [
        # users
        "ALTER TABLE users ADD COLUMN IF NOT EXISTS current_device_id VARCHAR(255);",
        "ALTER TABLE users ADD COLUMN IF NOT EXISTS suspended BOOLEAN DEFAULT FALSE;",
        "ALTER TABLE users ADD COLUMN IF NOT EXISTS is_suspended BOOLEAN DEFAULT FALSE;",
        "ALTER TABLE users ADD COLUMN IF NOT EXISTS email VARCHAR(160) DEFAULT '';",
        "ALTER TABLE users ADD COLUMN IF NOT EXISTS phone VARCHAR(20) DEFAULT '';",
        "ALTER TABLE users ADD COLUMN IF NOT EXISTS role VARCHAR(80) DEFAULT 'staff';",
        "ALTER TABLE users ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE;",
        "ALTER TABLE users ADD COLUMN IF NOT EXISTS kiosk_enabled BOOLEAN DEFAULT TRUE;",
        # other_staff
        "ALTER TABLE other_staff ADD COLUMN IF NOT EXISTS current_device_id VARCHAR(255);",
        "ALTER TABLE other_staff ADD COLUMN IF NOT EXISTS suspended BOOLEAN DEFAULT FALSE;",
        "ALTER TABLE other_staff ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE;",
        "ALTER TABLE other_staff ADD COLUMN IF NOT EXISTS email VARCHAR(160) DEFAULT '';",
        "ALTER TABLE other_staff ADD COLUMN IF NOT EXISTS phone VARCHAR(20) DEFAULT '';",
        # students
        "ALTER TABLE students ADD COLUMN IF NOT EXISTS current_device_id VARCHAR(255);",
        "ALTER TABLE students ADD COLUMN IF NOT EXISTS suspended BOOLEAN DEFAULT FALSE;",
        "ALTER TABLE students ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE;",
        "ALTER TABLE students ADD COLUMN IF NOT EXISTS first_time_login BOOLEAN DEFAULT TRUE;",
        "ALTER TABLE students ADD COLUMN IF NOT EXISTS year INT DEFAULT 1;",
        "ALTER TABLE students ADD COLUMN IF NOT EXISTS roll_no VARCHAR(64);",
        # departments
        "ALTER TABLE departments ADD COLUMN IF NOT EXISTS dept_name VARCHAR(100);",
        "UPDATE departments SET dept_name = name WHERE dept_name IS NULL;",
        # leave action history
        "ALTER TABLE student_leave_od_action_history ALTER COLUMN action_by DROP NOT NULL;",
        "ALTER TABLE student_leave_od_action_history ALTER COLUMN action_by_role DROP NOT NULL;",
    ]

    repaired = 0
    with conn.cursor() as cur:
        for stmt in ddl_statements:
            try:
                cur.execute(stmt)
                repaired += 1
            except Exception:
                pass
    return repaired


def detect_hash_type(hash_str):
    if not hash_str:
        return "EMPTY / NULL"
    h = str(hash_str).strip()
    if h.startswith(("$2a$", "$2b$", "$2y$", "$2x$")):
        return f"BCRYPT ({len(h)} chars)"
    elif len(h) == 64 and all(c in "0123456789abcdefABCDEF" for c in h):
        return "SHA-256"
    elif len(h) == 32 and all(c in "0123456789abcdefABCDEF" for c in h):
        return "MD5"
    elif len(h) == 128 and all(c in "0123456789abcdefABCDEF" for c in h):
        return "SHA-512"
    else:
        return f"PLAINTEXT / UNHASHED ({len(h)} chars)"


def verify_password_simulation(plain_pw, hash_str):
    if not plain_pw or not hash_str:
        return False
    pw = str(plain_pw).strip()
    h = str(hash_str).strip()

    # Plaintext
    if pw == h:
        return True

    # Bcrypt
    if h.startswith(("$2a$", "$2b$", "$2y$", "$2x$")):
        try:
            return bcrypt.checkpw(pw.encode("utf-8"), h.encode("utf-8"))
        except Exception:
            return False

    # SHA256
    if len(h) == 64 and hashlib.sha256(pw.encode("utf-8")).hexdigest().lower() == h.lower():
        return True

    # MD5
    if len(h) == 32 and hashlib.md5(pw.encode("utf-8")).hexdigest().lower() == h.lower():
        return True

    return False


def audit_accounts(conn, port):
    print("=" * 80)
    print(f"  VisionGate Database Authentication Audit (Connected on Port {port})")
    print("=" * 80)

    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        # Check users
        cur.execute("SELECT id, username, reg_no, name, dept, role, password_hash, suspended FROM users ORDER BY id ASC")
        users = cur.fetchall()
        print(f"\n[+] 'users' Table ({len(users)} registered records):")
        print(f" {'ID':<5} {'Username':<18} {'Reg No':<14} {'Role':<10} {'Dept':<18} {'Hash Type':<22} {'Suspended'}")
        print("-" * 105)
        for u in users:
            ht = detect_hash_type(u.get("password_hash"))
            susp = "YES" if u.get("suspended") else "No"
            print(f" {u.get('id'):<5} {u.get('username') or '—':<18} {u.get('reg_no') or '—':<14} {u.get('role') or '—':<10} {(u.get('dept') or '')[:17]:<18} {ht:<22} {susp}")

        # Check other_staff
        cur.execute("SELECT id, username, reg_no, name, dept, role, password_hash FROM other_staff ORDER BY id ASC")
        other = cur.fetchall()
        if other:
            print(f"\n[+] 'other_staff' Table ({len(other)} records):")
            print(f" {'ID':<5} {'Username':<18} {'Reg No':<14} {'Role':<14} {'Dept':<18} {'Hash Type'}")
            print("-" * 90)
            for o in other:
                ht = detect_hash_type(o.get("password_hash"))
                print(f" {o.get('id'):<5} {o.get('username') or '—':<18} {o.get('reg_no') or '—':<14} {o.get('role') or '—':<14} {(o.get('dept') or '')[:17]:<18} {ht}")

        # Check students summary
        cur.execute("SELECT count(*) as total, count(NULLIF(password_hash, '')) as with_pw FROM students")
        stu_stats = cur.fetchone()
        print(f"\n[+] 'students' Table: {stu_stats['total']} total students ({stu_stats['with_pw']} with custom password_hash; remainder authenticate via DOB variants).")


def reset_user_password(conn, username, new_password):
    clean_user = username.strip()
    pw_hash = bcrypt.hashpw(new_password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")

    with conn.cursor() as cur:
        # Check users
        cur.execute("UPDATE users SET password_hash = %s WHERE LOWER(TRIM(username)) = LOWER(%s) OR LOWER(TRIM(reg_no)) = LOWER(%s) RETURNING id, username, role", (pw_hash, clean_user, clean_user))
        row = cur.fetchone()
        if row:
            print(f"[✓] Successfully reset password for user '{row[1]}' (Role: {row[2]}, ID: {row[0]}) in 'users' table.")
            return True

        # Check other_staff
        cur.execute("UPDATE other_staff SET password_hash = %s WHERE LOWER(TRIM(username)) = LOWER(%s) OR LOWER(TRIM(reg_no)) = LOWER(%s) RETURNING id, username, role", (pw_hash, clean_user, clean_user))
        row = cur.fetchone()
        if row:
            print(f"[✓] Successfully reset password for user '{row[1]}' (Role: {row[2]}, ID: {row[0]}) in 'other_staff' table.")
            return True

        print(f"[✗] Error: User '{username}' was not found in 'users' or 'other_staff'.")
        return False


def test_login(conn, username, password):
    clean_user = username.strip()
    print(f"[*] Testing simulated authentication for '{clean_user}'...")

    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        # 1. Check users table
        cur.execute(
            "SELECT id, username, reg_no, name, dept, role, password_hash, suspended FROM users WHERE LOWER(TRIM(username)) = LOWER(%s) OR LOWER(TRIM(reg_no)) = LOWER(%s) OR LOWER(TRIM(email)) = LOWER(%s)",
            (clean_user, clean_user, clean_user)
        )
        user = cur.fetchone()
        if user:
            print(f"[+] Found in 'users' table: ID {user['id']}, Username: '{user['username']}', RegNo: '{user['reg_no']}', Role: '{user['role']}'")
            hash_type = detect_hash_type(user['password_hash'])
            print(f"    Password format in DB: {hash_type}")

            if user.get("suspended"):
                print("[✗] AUTH FAILED: Account is marked as SUSPENDED.")
                return False

            if verify_password_simulation(password, user['password_hash']):
                print("[✓] AUTH SUCCESS: Password verified successfully!")
                return True
            else:
                print(f"[✗] AUTH FAILED: Provided password does not match stored hash ({hash_type}).")
                return False

        # 2. Check other_staff table
        cur.execute(
            "SELECT id, username, reg_no, name, dept, role, password_hash FROM other_staff WHERE LOWER(TRIM(username)) = LOWER(%s) OR LOWER(TRIM(reg_no)) = LOWER(%s)",
            (clean_user, clean_user)
        )
        os_user = cur.fetchone()
        if os_user:
            print(f"[+] Found in 'other_staff' table: ID {os_user['id']}, Role: '{os_user['role']}'")
            if verify_password_simulation(password, os_user['password_hash']):
                print("[✓] AUTH SUCCESS: Other staff password verified successfully!")
                return True
            else:
                print("[✗] AUTH FAILED: Incorrect password for other_staff.")
                return False

        print(f"[✗] AUTH FAILED: User '{clean_user}' not found in database.")
        return False


def main():
    parser = argparse.ArgumentParser(description="VisionGate Linux Database & Auth Diagnostic Utility")
    parser.add_argument("--audit", action="store_true", help="Audit all accounts, roles, and password hash formats")
    parser.add_argument("--auto-repair", action="store_true", help="Auto-repair missing database schema columns")
    parser.add_argument("--reset-user", nargs=2, metavar=("USERNAME", "NEW_PASSWORD"), help="Reset password for an existing account")
    parser.add_argument("--test-login", nargs=2, metavar=("USERNAME", "PASSWORD"), help="Test authentication credentials")
    args = parser.parse_args()

    conn, port = get_db_connection()
    if not conn:
        print("[✗] Error: Unable to connect to PostgreSQL on port 5434 or 5432.")
        sys.exit(1)

    # Auto repair columns first
    repaired = ensure_schema_columns(conn)
    if args.auto_repair:
        print(f"[✓] Database schema verified: {repaired} DDL compatibility statements executed.")

    if args.reset_user:
        reset_user_password(conn, args.reset_user[0], args.reset_user[1])
    elif args.test_login:
        test_login(conn, args.test_login[0], args.test_login[1])
    else:
        audit_accounts(conn, port)


if __name__ == "__main__":
    main()
