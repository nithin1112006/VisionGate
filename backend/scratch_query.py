import pg_adapter

cursor = pg_adapter.cursor
cursor.execute("SELECT reg_no, user_name, balance FROM earned_leave WHERE reg_no = 'HOD_0001'")
print("earned_leave record:")
print(cursor.fetchall())

cursor.execute("SELECT reg_no, name, earned_points, date, slot_type FROM ccl_earned_history WHERE reg_no = 'HOD_0001'")
print("ccl_earned_history records:")
print(cursor.fetchall())
