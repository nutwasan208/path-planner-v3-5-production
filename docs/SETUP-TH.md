# นักวางแผนเส้นทาง v3.0 — Phase 1 Cloud Foundation

โครงการนี้เชื่อมเกมเดิมกับ Supabase Database และ Supabase Auth และเตรียมพร้อมสำหรับ Netlify

## สิ่งที่ทำแล้วใน Phase 1
- นักเรียนกรอกชื่อ ชั้นเรียน และเลขที่
- สร้างรอบการเล่นใหม่ทุกครั้ง
- บันทึกผลรายด่าน: เวลา คะแนน ดาว จำนวนผิด และจำนวนคำใบ้
- รวมข้อมูลจากทุกอุปกรณ์ใน Supabase
- มีคิวสำรองใน localStorage เมื่อส่งผลไม่สำเร็จ และลองซิงก์เมื่อออนไลน์
- ครูเข้าสู่ระบบด้วย Supabase Auth ผ่านไอคอนฟันเฟือง
- Dashboard เดิมดึงข้อมูลออนไลน์ขั้นพื้นฐานแล้ว
- RLS เปิดทุกตาราง และนักเรียนไม่สามารถอ่านตารางโดยตรง

## ขั้นตอนติดตั้ง
1. สร้าง Supabase Project
2. เปิด SQL Editor แล้วรัน `supabase/phase1_schema.sql`
3. แก้ชื่อโรงเรียนใน Table Editor > `school_settings`
4. เพิ่มห้องเรียนอย่างน้อย 1 ห้องใน `classes` เช่น `ป.1/1`
5. ไป Authentication > Users > Add user แล้วสร้างบัญชีครู
6. คัดลอก UUID ของบัญชีครู แล้วรัน SQL:
```sql
insert into public.teacher_profiles(user_id,display_name,role)
values ('UUID_บัญชีครู','ชื่อครู','admin');
```
7. ใน Supabase Project Settings > API คัดลอก Project URL และ Publishable/anon key
8. ใน Netlify > Project configuration > Environment variables เพิ่ม:
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
   - `GAME_SLUG=path-planner`
   - `ACADEMIC_YEAR=2569`
   - `TERM=1`
9. อัปโหลดโฟลเดอร์นี้ผ่าน Git หรือ Netlify แล้วให้ Build command เป็น `npm run build` และ Publish directory เป็น `public`

## ทดสอบในเครื่อง
คัดลอก `.env.example` เป็น `.env` ใส่ค่าจริง แล้วใช้ Netlify CLI:
```bash
netlify dev
```

## ความปลอดภัย
- ห้ามใช้ `service_role` key ในไฟล์เว็บหรือ Netlify build ที่จะถูกฝังสู่ browser
- ใช้เฉพาะ Publishable/anon key ร่วมกับ RLS และ RPC ที่กำหนดไว้
- ปิดการสมัครสมาชิกสาธารณะใน Supabase Auth และให้ผู้ดูแลสร้างบัญชีครู

## ขอบเขต Phase 1
Dashboard ในรุ่นนี้เป็นข้อมูลรวมขั้นพื้นฐาน ส่วนการสร้างห้องผ่าน UI, ตัวกรอง, leaderboard, realtime, export รายงาน และการวิเคราะห์เชิงลึกจะพัฒนาใน Phase 2–3

## ติดตั้ง Phase 3

หลังรัน Phase 1 และ Phase 2 แล้ว ให้นำ `supabase/phase3_migration.sql` ไปรันใน Supabase SQL Editor เป็นลำดับสุดท้าย ระบบจึงจะแสดงเกณฑ์ประเมินและบันทึกค่าการวิเคราะห์ได้


# การอัปเกรดเป็น Path Planner v3.5
1. รัน `supabase/phase35_migration.sql` ใน SQL Editor หลังไฟล์ Phase 1–3
2. ใน Netlify เพิ่ม Environment Variable `TEACHER_EMAIL` ให้ตรงกับบัญชีใน Supabase Authentication
3. ตัวแปรที่ต้องมี: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `TEACHER_EMAIL`, `GAME_SLUG`, `ACADEMIC_YEAR`, `TERM`
4. Deploy โปรเจกต์ใหม่ แล้วเข้าสู่ Dashboard ด้วยรหัสผ่านเพียงช่องเดียว
