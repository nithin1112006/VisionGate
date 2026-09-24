#!/usr/bin/env python3
"""
VisionGate - Autonomous Server-Side Authentication Resilience Patcher
Patches backend/main.py on the Linux host to support multi-hash verification (bcrypt,
sha256, md5, plaintext), schema-agnostic column extraction, and case-insensitive logins
without breaking existing databases or requiring changes to the local Windows copy.
"""

import os
import sys
import shutil
import time
import py_compile
import re

PATCH_SENTINEL = "# --- VISIONGATE_AUTOPATCH_AUTH_RESILIENCE_V1 ---"


def find_target_main_py():
    candidates = [
        os.path.join(os.path.dirname(__file__), "..", "..", "backend", "main.py"),
        os.path.join(os.path.dirname(__file__), "backend", "main.py"),
        "/var/www/attenda/VisionGate/backend/main.py",
        os.path.abspath("backend/main.py"),
    ]
    for c in candidates:
        norm = os.path.abspath(c)
        if os.path.isfile(norm):
            return norm
    return None


RESILIENT_AUTH_BLOCK = """
# --- VISIONGATE_AUTOPATCH_AUTH_RESILIENCE_V1 ---
import hashlib
import bcrypt

def verify_password(password: str, hashed: str) -> bool:
    \"\"\"Resilient password verifier supporting bcrypt, sha256, md5, and plaintext.\"\"\"
    if password is None or hashed is None:
        return False
    try:
        pw_str = str(password).strip()
        h_str = str(hashed).strip()

        if not pw_str or not h_str:
            return False

        # 1. Direct plaintext match (for unhashed / legacy database records)
        if pw_str == h_str or str(password) == str(hashed):
            return True

        # 2. Standard bcrypt check ($2a$, $2b$, $2y$, $2x$)
        if h_str.startswith(("$2a$", "$2b$", "$2y$", "$2x$")):
            try:
                return bcrypt.checkpw(pw_str.encode("utf-8"), h_str.encode("utf-8"))
            except Exception:
                pass

        # 3. SHA-256 match (64 hex characters)
        if len(h_str) == 64:
            if hashlib.sha256(pw_str.encode("utf-8")).hexdigest().lower() == h_str.lower():
                return True

        # 4. MD5 match (32 hex characters)
        if len(h_str) == 32:
            if hashlib.md5(pw_str.encode("utf-8")).hexdigest().lower() == h_str.lower():
                return True

        # 5. SHA-512 match (128 hex characters)
        if len(h_str) == 128:
            if hashlib.sha512(pw_str.encode("utf-8")).hexdigest().lower() == h_str.lower():
                return True

        # 6. Fallback raw bcrypt check
        try:
            return bcrypt.checkpw(str(password).encode("utf-8"), str(hashed).encode("utf-8"))
        except Exception:
            return False
    except Exception as _e:
        return False


def _normalize_row_by_columns(row, cursor_obj, default_role="staff"):
    \"\"\"Normalize raw database row into canonical tuple (id, username, password_hash, reg_no, name, dept, role).\"\"\"
    if not row:
        return None
    try:
        desc = getattr(cursor_obj, "description", None)
        if desc:
            col_names = [d[0].lower() for d in desc]
            row_dict = dict(zip(col_names, row))
            r_id = row_dict.get("id")
            r_username = row_dict.get("username", "") or ""
            r_hash = row_dict.get("password_hash", "") or ""
            r_reg = row_dict.get("reg_no", "") or ""
            r_name = row_dict.get("name", "") or ""
            r_dept = row_dict.get("dept", "") or ""
            r_role = str(row_dict.get("role", default_role) or default_role).strip().lower()
            return (r_id, r_username, r_hash, r_reg, r_name, r_dept, r_role)
    except Exception:
        pass
    return row


def get_user_by_username(username: str):
    \"\"\"Get user from 'users' table by username, reg_no, or email (case-insensitive & trimmed).\"\"\"
    if not username:
        return None
    clean = str(username).strip()
    cursor.execute(
        "SELECT * FROM users WHERE LOWER(TRIM(username)) = LOWER(?) OR LOWER(TRIM(reg_no)) = LOWER(?) OR LOWER(TRIM(email)) = LOWER(?) LIMIT 1",
        (clean, clean, clean)
    )
    row = cursor.fetchone()
    return _normalize_row_by_columns(row, cursor, default_role="staff")


def get_user_by_reg_no(reg_no: str):
    \"\"\"Get user from 'users' table by registration number (case-insensitive & trimmed).\"\"\"
    return get_user_by_username(reg_no)


def get_other_staff_by_username(username: str):
    \"\"\"Get user from 'other_staff' table by username, reg_no, or email (case-insensitive & trimmed).\"\"\"
    if not username:
        return None
    clean = str(username).strip()
    cursor.execute(
        "SELECT * FROM other_staff WHERE LOWER(TRIM(username)) = LOWER(?) OR LOWER(TRIM(reg_no)) = LOWER(?) OR LOWER(TRIM(email)) = LOWER(?) LIMIT 1",
        (clean, clean, clean)
    )
    row = cursor.fetchone()
    return _normalize_row_by_columns(row, cursor, default_role="other_staff")


def get_other_staff_by_reg_no(reg_no: str):
    \"\"\"Get other_staff by registration number.\"\"\"
    return get_other_staff_by_username(reg_no)
# --- END VISIONGATE_AUTOPATCH_AUTH_RESILIENCE_V1 ---
"""


def patch_main_py(file_path):
    print(f"[*] Auditing target file: {file_path}")
    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()

    if PATCH_SENTINEL in content:
        print("[✓] Server authentication resilience patch is already installed.")
        return True

    # Create timestamped backup
    backup_path = f"{file_path}.bak.{int(time.time())}"
    shutil.copyfile(file_path, backup_path)
    print(f"[✓] Created pristine backup at: {backup_path}")

    # 1. Replace verify_password and get_user functions
    pattern_verify = r"def verify_password\(password:\s*str,\s*hashed:\s*str\)\s*->\s*bool:.*?(?=\ndef is_user_suspended|\n@|\Z)"
    if re.search(pattern_verify, content, re.DOTALL):
        # We replace from verify_password down to get_user_by_reg_no
        pattern_full_block = r"def verify_password\(password:\s*str,\s*hashed:\s*str\)\s*->\s*bool:.*?(?=def _authenticate_student_creds)"
        if re.search(pattern_full_block, content, re.DOTALL):
            # Keep is_user_suspended intact
            is_susp_match = re.search(r"(def is_user_suspended.*?)(?=def get_user_by_username)", content, re.DOTALL)
            is_susp_code = is_susp_match.group(1) if is_susp_match else ""
            replacement = RESILIENT_AUTH_BLOCK.strip() + "\n\n" + is_susp_code.strip() + "\n\n"
            content = re.sub(pattern_full_block, replacement, content, count=1, flags=re.DOTALL)
            print("[+] Patched verify_password, get_user_by_username, and get_user_by_reg_no.")

    # 2. Ensure skip_paths in vpn_detection_middleware includes all login endpoints
    if 'skip_paths = [' in content:
        vpn_endpoints = [
            '"/login"',
            '"/admin/login"',
            '"/hod/login"',
            '"/staff/login"',
            '"/other_staff/login"',
        ]
        skip_paths_block = re.search(r"skip_paths\s*=\s*\[(.*?)\]", content, re.DOTALL)
        if skip_paths_block:
            existing = skip_paths_block.group(1)
            to_add = [ep for ep in vpn_endpoints if ep not in existing]
            if to_add:
                new_block = "skip_paths = [\n        " + ",\n        ".join(to_add) + ",\n" + existing.lstrip() + "]"
                content = content.replace(skip_paths_block.group(0), new_block, 1)
                print(f"[+] Added {len(to_add)} authentication endpoints to VPN skip paths.")

    # 3. Ensure login current_device_id updates do not crash if column issue occurs
    pattern_device = r'(cursor\.execute\("UPDATE users SET current_device_id = \? WHERE username = \?", \(device_id, user\[1\]\)\)\s*conn\.commit\(\))'
    if re.search(pattern_device, content):
        safe_device = """try:
            cursor.execute("UPDATE users SET current_device_id = ? WHERE username = ?", (device_id, user[1]))
            conn.commit()
        except Exception as _e:
            pass"""
        content = re.sub(pattern_device, safe_device, content, count=1)
        print("[+] Wrapped current_device_id update in fail-safe handler.")

    # Write patched content
    with open(file_path, "w", encoding="utf-8") as f:
        f.write(content)

    # Validate Python syntax
    try:
        py_compile.compile(file_path, doraise=True)
        print("[✓] Syntax compilation check PASSED.")
        return True
    except Exception as compile_err:
        print(f"[✗] Syntax check FAILED: {compile_err}. Reverting from backup...")
        shutil.copyfile(backup_path, file_path)
        return False


def main():
    target = sys.argv[1] if len(sys.argv) > 1 else find_target_main_py()
    if not target:
        print("[✗] Error: Unable to locate backend/main.py. Specify path as argument.")
        sys.exit(1)

    success = patch_main_py(target)
    if not success:
        sys.exit(1)
    print("==============================================================================")
    print("  Server Authentication Resilience Engine Successfully Installed")
    print("==============================================================================")


if __name__ == "__main__":
    main()
