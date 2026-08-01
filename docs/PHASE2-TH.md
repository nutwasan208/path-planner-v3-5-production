# Phase 2 — Dashboard ครูออนไลน์

## เพิ่มจาก Phase 1
- หน้า `dashboard.html` แยกสำหรับครู
- Supabase Auth พร้อมตรวจสอบ `teacher_profiles`
- ตัวกรองห้อง วันที่ และเกม
- สถิติรวม กราฟเวลา กราฟผู้ผ่านด่าน
- Leaderboard ทั้งโรงเรียน
- รายละเอียดนักเรียนและประวัติทุกครั้งที่เล่น
- สร้างและแก้ไขห้องเรียน
- Export CSV
- Realtime refresh เมื่อมีข้อมูลใหม่
- Responsive สำหรับมือถือและคอมพิวเตอร์

## การติดตั้งฐานข้อมูล
1. รัน `supabase/phase1_schema.sql` หากยังไม่เคยรัน
2. รัน `supabase/phase2_migration.sql`
3. สร้างผู้ใช้ครูใน Authentication > Users
4. เพิ่ม UUID ลง `teacher_profiles`

## การเปิดใช้งาน
- นักเรียน: `/index.html`
- ครู: กด ⚙️ หน้าแรก หรือเปิด `/dashboard.html`

## หมายเหตุ
Dashboard อ่านข้อมูลทั้งหมดได้เฉพาะบัญชีที่มีแถวใน `teacher_profiles` และ `is_active=true`
