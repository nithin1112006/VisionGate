"""
Seed database script for VisionGate / Attenda.
Populates departments, staff members across departments, other staff, and students.
"""

import sys
import os

sys.path.insert(0, os.path.dirname(__file__))

import bcrypt
import pg_adapter

cursor = pg_adapter.cursor


def hash_pw(pw):
    return bcrypt.hashpw(pw.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')


def run_seed():
    print("Starting database seeding...")

    # 1. Seed Departments
    depts = [
        'CSE',
        'ECE',
        'EEE',
        'MECH',
        'CIVIL',
        'IT',
        'AI & ML',
        'Data Science',
        'Administration',
    ]
    inserted_depts = 0
    for d in depts:
        try:
            cursor.execute('SELECT id FROM departments WHERE name = ?', (d,))
            if not cursor.fetchone():
                cursor.execute('INSERT INTO departments (name) VALUES (?)', (d,))
                inserted_depts += 1
        except Exception as e:
            print(f"Error seeding dept {d}: {e}")
    print(f"Departments: {inserted_depts} inserted.")

    # 2. Seed Users (Admin, HODs, Staff)
    users = [
        ('admin', 'admin123', 'ADMIN001', 'System Administrator', 'Administration', 'admin', 'system'),
        ('demo', 'demo123', 'STAFF_0002', 'Prof. Demo User', 'CSE', 'staff', 'admin'),
        ('demoo', 'demoo123', 'STAFF_0001', 'Prof. Demoo User', 'CSE', 'staff', 'admin'),
        ('hodcse', 'hod123', 'HOD_0001', 'Dr. John Smith', 'CSE', 'hod', 'admin'),
        ('hod_cs', 'hod123', 'HOD001', 'Dr. John Smith', 'CSE', 'hod', 'admin'),
        ('hod_ec', 'hod123', 'HOD002', 'Dr. Sarah Johnson', 'ECE', 'hod', 'admin'),
        ('hod_ee', 'hod123', 'HOD003', 'Dr. James Wilson', 'EEE', 'hod', 'admin'),
        ('hod_me', 'hod123', 'HOD004', 'Dr. Maria Garcia', 'MECH', 'hod', 'admin'),
        ('hod_ce', 'hod123', 'HOD005', 'Dr. Robert Chen', 'CIVIL', 'hod', 'admin'),
        ('hod_it', 'hod123', 'HOD006', 'Dr. Priya Sharma', 'IT', 'hod', 'admin'),
        ('hod_ai', 'hod123', 'HOD007', 'Dr. Ahmed Khan', 'AI & ML', 'hod', 'admin'),
        ('hod_ds', 'hod123', 'HOD008', 'Dr. Lisa Park', 'Data Science', 'hod', 'admin'),
        ('staff001', 'staff123', 'STAFF001', 'Prof. Michael Brown', 'CSE', 'staff', 'hod_cs'),
        ('staff002', 'staff123', 'STAFF002', 'Prof. Emily Davis', 'CSE', 'staff', 'hod_cs'),
        ('staff003', 'staff123', 'STAFF003', 'Prof. Robert Wilson', 'ECE', 'staff', 'hod_ec'),
        ('staff004', 'staff123', 'STAFF004', 'Prof. Anna Lee', 'ECE', 'staff', 'hod_ec'),
        ('staff005', 'staff123', 'STAFF005', 'Prof. David Kim', 'EEE', 'staff', 'hod_ee'),
        ('staff006', 'staff123', 'STAFF006', 'Prof. Sarah Miller', 'MECH', 'staff', 'hod_me'),
        ('staff007', 'staff123', 'STAFF007', 'Prof. Tom Harris', 'CIVIL', 'staff', 'hod_ce'),
        ('staff008', 'staff123', 'STAFF008', 'Prof. Nina Patel', 'IT', 'staff', 'hod_it'),
        ('staff009', 'staff123', 'STAFF009', 'Prof. Alex Turner', 'AI & ML', 'staff', 'hod_ai'),
        ('staff010', 'staff123', 'STAFF010', 'Prof. Rachel Green', 'Data Science', 'staff', 'hod_ds'),
    ]

    inserted_users = 0
    for uname, pw, reg, name, dept, role, cb in users:
        try:
            cursor.execute('SELECT id FROM users WHERE username = ? OR LOWER(reg_no) = LOWER(?)', (uname, reg))
            if not cursor.fetchone():
                h = hash_pw(pw)
                cursor.execute(
                    'INSERT INTO users (username, password_hash, reg_no, name, dept, role, created_by) VALUES (?, ?, ?, ?, ?, ?, ?)',
                    (uname, h, reg, name, dept, role, cb)
                )
                inserted_users += 1
        except Exception as e:
            print(f"Error seeding user {uname}: {e}")
    print(f"Users: {inserted_users} inserted.")

    # 3. Seed Other Staff
    other_staff = [
        ('principal', 'principal123', 'PRINCIPAL001', 'Dr. ABC Principal', '1970-01-01', 'principal', 'Administration', 'system'),
        ('placement_staff', 'placement123', 'PLACE001', 'Mr. XYZ Placement Officer', '1985-05-15', 'placement_staff', 'Placement Staff', 'admin'),
        ('lab_tech', 'labtech123', 'LAB001', 'Mr. PQR Lab Technician', '1990-08-20', 'lab_technician', 'CSE', 'admin'),
        ('sys_admin', 'sysadmin123', 'SYS001', 'Mr. LMN System Admin', '1988-03-10', 'system_admin', 'System Admin', 'admin'),
        ('office_staff', 'office123', 'OFFICE001', 'Ms. Office Staff', '1992-07-10', 'office_staff', 'Office Staff', 'admin'),
    ]
    inserted_other = 0
    for uname, pw, reg, name, dob, role, dept, cb in other_staff:
        try:
            cursor.execute('SELECT id FROM other_staff WHERE username = ? OR LOWER(reg_no) = LOWER(?)', (uname, reg))
            if not cursor.fetchone():
                h = hash_pw(pw)
                cursor.execute(
                    'INSERT INTO other_staff (username, password_hash, reg_no, name, dob, role, dept, created_by) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
                    (uname, h, reg, name, dob, role, dept, cb)
                )
                inserted_other += 1
        except Exception as e:
            print(f"Error seeding other_staff {uname}: {e}")
    print(f"Other staff: {inserted_other} inserted.")

    # 4. Seed Students & Student Face Profiles
    students_data = [
        ('714024104145', 'NITHIN K V', 'CSE', 'STAFF_0002'),
        ('714024104146', 'Aravind Swamy', 'CSE', 'STAFF_0002'),
        ('714024104147', 'Bhavana R', 'CSE', 'STAFF_0001'),
        ('138', 'Naveen Kumar', 'CSE', 'STAFF_0001'),
        ('714024201001', 'Kavitha M', 'ECE', 'STAFF003'),
        ('714024201002', 'Karthik S', 'ECE', 'STAFF004'),
        ('714024301001', 'Dinesh Kumar', 'EEE', 'STAFF005'),
        ('714024401001', 'Manish V', 'MECH', 'STAFF006'),
        ('714024501001', 'Pooja R', 'CIVIL', 'STAFF007'),
        ('714024601001', 'Rahul Dravid', 'IT', 'STAFF008'),
        ('714024701001', 'Siddharth M', 'AI & ML', 'STAFF009'),
        ('714024801001', 'Tejaswini K', 'Data Science', 'STAFF010'),
    ]
    inserted_students = 0
    for reg, name, dept, reg_by in students_data:
        try:
            cursor.execute('SELECT reg_no FROM student_face_profiles WHERE LOWER(reg_no) = LOWER(?)', (reg,))
            if not cursor.fetchone():
                cursor.execute(
                    'INSERT INTO student_face_profiles (reg_no, name, dept, registered_by, embeddings) VALUES (?, ?, ?, ?, ?)',
                    (reg, name, dept, reg_by, '[]')
                )
                inserted_students += 1

            cursor.execute('SELECT reg_no FROM students WHERE LOWER(reg_no) = LOWER(?)', (reg,))
            if not cursor.fetchone():
                cursor.execute(
                    'INSERT INTO students (reg_no, name, dept, embedding) VALUES (?, ?, ?, ?)',
                    (reg, name, dept, '[]')
                )
        except Exception as e:
            print(f"Error seeding student {reg}: {e}")
    print(f"Students & Face Profiles: {inserted_students} inserted.")
    print("Database seeding completed successfully!")


if __name__ == '__main__':
    run_seed()
