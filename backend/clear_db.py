import os
import bcrypt
import psycopg2
from psycopg2.extensions import ISOLATION_LEVEL_AUTOCOMMIT
from dotenv import load_dotenv

load_dotenv(os.path.join(os.path.dirname(__file__), ".env"))

TABLES = [
    "face_reregister_requests",
    "leave_request_audit_log",
    "leave_requests",
    "casual_leave",
    "daily_attendance_status",
    "attendance",
    "other_staff_attendance",
    "user_latest_locations",
    "user_location_logs",
    "user_locations",
    "attendance_locations",
    "face_embedding_samples",
    "face_training_runs",
    "app_settings",
    "system_config",
    "attendance_duration_settings",
    "geo_fence_coordinates",
    "geo_fence_coordinates_v2",
    "geo_fence_points",
    "academic_year_config",
    "holidays",
    "departments",
    "admin_notifications",
    "students",
    "other_staff",
    "users",
]


def clear_database():
    conn = psycopg2.connect(
        host=os.environ.get("PG_HOST", "127.0.0.1"),
        port=int(os.environ.get("PG_PORT", "5432")),
        dbname=os.environ.get("PG_DB", "attenda"),
        user=os.environ.get("PG_USER", "attenda"),
        password=os.environ.get("PG_PASSWORD", "attenda_password"),
    )
    conn.set_isolation_level(ISOLATION_LEVEL_AUTOCOMMIT)
    cur = conn.cursor()

    try:
        cur.execute("SELECT EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public')")
        if not cur.fetchone()[0]:
            print("No tables found in public schema.")
            return

        for table in TABLES:
            try:
                cur.execute(f"TRUNCATE TABLE {table} CASCADE")
                print(f"Cleared: {table}")
            except psycopg2.errors.UndefinedTable:
                conn.rollback()
                print(f"Skipped (table not found): {table}")
            except Exception as e:
                conn.rollback()
                print(f"Error clearing {table}: {e}")

        cur.execute("SELECT relname FROM pg_class WHERE relkind = 'S' AND relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')")
        sequences = cur.fetchall()
        for seq in sequences:
            try:
                cur.execute(f"ALTER SEQUENCE {seq[0]} RESTART WITH 1")
            except Exception:
                pass

        pw_hash = bcrypt.hashpw(b"admin123", bcrypt.gensalt()).decode("utf-8")
        cur.execute(
            "INSERT INTO users (username, password_hash, reg_no, name, dept, role, created_by) VALUES (%s, %s, %s, %s, %s, %s, %s)",
            ("admin", pw_hash, "ADMIN001", "System Administrator", "Administration", "admin", "system"),
        )
        print("Re-inserted admin user (username: admin, password: admin123)")

        print("\nAll tables cleared successfully.")
    except Exception as e:
        print(f"Error: {e}")
        raise
    finally:
        cur.close()
        conn.close()


if __name__ == "__main__":
    clear_database()
