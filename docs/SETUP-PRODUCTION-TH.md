# คู่มือติดตั้ง Path Planner v3.5 Production

## สถานะที่ต้องมีอยู่แล้ว

1. รัน `phase1_schema.sql`
2. รัน `phase2_migration.sql`
3. รัน `phase3_migration.sql`
4. รัน `phase35_migration.sql`
5. สร้างผู้ใช้ครูใน Authentication
6. เพิ่ม UID ของครู 1 แถวใน `teacher_profiles` โดย `role=admin` และ `is_active=true`

## ขั้นที่ 1: รัน SQL ขั้นสุดท้าย

เปิด Supabase → SQL Editor → New query แล้วคัดลอกไฟล์:

`supabase/production_hardening.sql`

กด Run และต้องขึ้น Success ไฟล์นี้ทำให้ View เคารพ RLS, ตรวจสอบข้อมูลจากนักเรียนฝั่งเซิร์ฟเวอร์, ใช้ปีการศึกษา/ภาคเรียนจากโรงเรียน และเพิ่มดัชนีสำหรับ Dashboard

## ขั้นที่ 2: เตรียมค่าเชื่อมต่อ

เก็บไว้กับตัวเอง 3 ค่า:

- Project URL รูปแบบ `https://PROJECT_REF.supabase.co`
- Publishable key ขึ้นต้น `sb_publishable_...` หรือ anon key รุ่นเก่า
- อีเมลบัญชีครูที่สร้างใน Authentication

ห้ามใช้ Secret key และ service_role

## ขั้นที่ 3: นำขึ้น Netlify

1. แตก ZIP ให้เห็น `package.json`, `netlify.toml`, `public`, `scripts`, `supabase`
2. อัปโหลดโปรเจกต์ผ่าน Git หรือ Netlify Deploy
3. ใน Site configuration → Environment variables เพิ่ม:

```
SUPABASE_URL=https://PROJECT_REF.supabase.co
SUPABASE_ANON_KEY=sb_publishable_xxxxx
TEACHER_EMAIL=อีเมลบัญชีครู
GAME_SLUG=path-planner
ACADEMIC_YEAR=2569
TERM=1
```

4. Build command: `npm run build`
5. Publish directory: `public`
6. Trigger deploy ใหม่

ระหว่าง Build ระบบจะตรวจไฟล์และสร้าง `public/js/runtime-config.js` อัตโนมัติ

## ขั้นที่ 4: ตั้งค่า URL ของ Supabase Auth

ไปที่ Supabase → Authentication → URL Configuration

- Site URL: URL หลักของ Netlify เช่น `https://ชื่อไซต์.netlify.app`
- Redirect URLs: เพิ่ม `https://ชื่อไซต์.netlify.app/**`

ระบบนี้ล็อกอินด้วยรหัสผ่านโดยตรง จึงไม่พึ่งอีเมลยืนยันในแต่ละครั้ง แต่ควรกำหนด URL ให้ถูกต้องสำหรับการจัดการ Auth ในอนาคต

## ขั้นที่ 5: ตั้งค่าครั้งแรกผ่าน Dashboard

1. เปิดหน้าเกม
2. กด ⚙️
3. กรอกรหัสผ่านบัญชีครู (อีเมลถูกกำหนดจาก Netlify เบื้องหลัง)
4. หากชื่อโรงเรียนยังเป็นค่าเริ่มต้น ระบบจะเปิดหน้าตั้งค่าให้อัตโนมัติ
5. ใส่ชื่อโรงเรียน ปีการศึกษา ภาคเรียน โลโก้ และสีหลัก
6. เพิ่มห้องเรียนอย่างน้อย 1 ห้อง

หลังเพิ่มห้องแล้ว หน้าเกมจะโหลดรายชื่อห้องจาก Supabase

## ขั้นที่ 6: ทดสอบจริง

1. เปิดเกมในโหมดไม่ระบุตัวตนหรือมือถือเครื่องที่หนึ่ง
2. กรอกชื่อ ห้อง และเลขที่ แล้วเล่นผ่านอย่างน้อย 1 ด่าน
3. เปิด Dashboard อีกเครื่องและกดรีเฟรช
4. ตรวจว่ามีนักเรียน รอบเล่น และผลด่านปรากฏ
5. ปิดอินเทอร์เน็ตก่อนเริ่มเกม ทดลองเล่น แล้วเปิดอินเทอร์เน็ตกลับ ระบบจะซิงก์คิวที่เก็บไว้เมื่อหน้าเกมทำงานและกลับมาออนไลน์

## การใช้งานประจำวัน

- ครูจัดการห้องและโรงเรียนจาก Dashboard ไม่ต้องเข้า Table Editor
- ส่งออก CSV ได้จากตารางต่าง ๆ
- สำรองข้อมูล JSON ก่อนกู้คืนทุกครั้ง
- เมื่อต้องเปลี่ยนปีการศึกษา ให้เปลี่ยนใน Dashboard และปรับ Environment Variables ให้ตรงกันในการ Deploy รอบถัดไป แม้ฐานข้อมูลฝั่งเซิร์ฟเวอร์จะยึดค่าจาก `school_settings` เป็นหลัก
