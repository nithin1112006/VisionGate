import pg_adapter
cursor = pg_adapter.cursor

_, cur = cursor._get_conn()
cur.execute("""
    SELECT column_name, data_type 
    FROM information_schema.columns 
    WHERE table_name = 'attendance_duration_settings'
""")
cols = cur.fetchall()
print("attendance_duration_settings table columns:")
for col in cols:
    print(f"  {col['column_name']} ({col['data_type']})")
