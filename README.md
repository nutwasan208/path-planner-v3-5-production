# Path Planner v3.5 Production Final

ระบบเกม “นักวางแผนเส้นทาง” พร้อมฐานข้อมูล Supabase และ Dashboard สำหรับครู ใช้งานบน Netlify ได้เป็นโปรเจกต์เดียว

## ความสามารถหลัก

- นักเรียนเล่นผ่านมือถือ แท็บเล็ต หรือคอมพิวเตอร์จากลิงก์เดียวกัน
- บันทึกชื่อ ห้อง เลขที่ รอบการเล่น เวลา คะแนน ดาว การตอบผิด และคำใบ้ลง Supabase
- เก็บทุกครั้งที่เล่นและรวมข้อมูลจากทุกอุปกรณ์
- มีคิวออฟไลน์: หากสร้างรอบออนไลน์ไม่สำเร็จ เกมจะเก็บรอบและผลไว้ในเครื่องและซิงก์เมื่อกลับมาออนไลน์
- ครูเข้าผ่านไอคอนฟันเฟืองและกรอกรหัสผ่านอย่างเดียว
- Dashboard แสดงตาราง กราฟ อันดับรวม รายบุคคล นักเรียนที่ควรติดตาม และรายงานประเมิน
- ตั้งค่าโรงเรียน เพิ่ม/แก้ไขห้อง นำเข้ารายชื่อ CSV สำรอง/กู้คืน JSON และเปลี่ยนรหัสผ่านได้จาก Dashboard

## ไฟล์สำคัญ

- `public/index.html` หน้าเกม
- `public/dashboard.html` Dashboard ครู
- `supabase/production_hardening.sql` SQL ขั้นสุดท้ายหลังจาก Phase 1–3.5
- `docs/SETUP-PRODUCTION-TH.md` คู่มือติดตั้งจนใช้งานจริง

## การ Build

Netlify ใช้:

- Build command: `npm run build`
- Publish directory: `public`

Environment variables ที่จำเป็น:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY` (Publishable key)
- `TEACHER_EMAIL`
- `GAME_SLUG=path-planner`
- `ACADEMIC_YEAR=2569`
- `TERM=1`

ห้ามใส่ Supabase Secret key หรือ `service_role` key ใน Netlify หรือไฟล์ฝั่งเว็บไซต์


## สถานะเวอร์ชัน Final

เวอร์ชัน 3.5.1 เพิ่มการใช้รายการห้องเรียนจากแคชเมื่ออินเทอร์เน็ตขัดข้อง ปรับการตรวจสิทธิ์ครูก่อนแสดง Dashboard และเปิด Realtime สำหรับตารางที่ Dashboard ติดตาม โดยไม่เปลี่ยนโครงสร้างฐานข้อมูลหลักที่ติดตั้งไว้แล้ว

## อัปเดตโหมดกรอกชื่ออย่างเดียว

เวอร์ชันนี้นำช่องชั้นเรียนและเลขที่ออกจากหน้าเริ่มเกมแล้ว ก่อน Deploy ให้รันไฟล์
`supabase/name_only_student_migration.sql` ใน Supabase SQL Editor หนึ่งครั้ง เพื่อให้ฐานข้อมูลรองรับข้อมูลนักเรียนที่ไม่มีชั้นเรียนและเลขที่


## Delete individual player history
Before deploying this release, run `supabase/delete_student_history_migration.sql` once in Supabase SQL Editor. The teacher dashboard then supports permanent deletion of one player's sessions and level results after a second confirmation click.


## Version 3.6 update

- Added a return-to-name button on the level-select screen while preserving the current player name and cloud session when unchanged.
- Added stable success voice audio with applause and mobile audio unlocking.
- Restored square 1:1 destination images in the win dialog while keeping all controls visible on mobile.
- Added a large fireworks celebration after completing level 10.
- Reworked the teacher dashboard into mobile cards so it no longer requires page zooming.


## v3.6.2
- ใช้เสียง final-cheer.mp3 เฉพาะเมื่อผ่านด่านที่ 10
- สรุปคะแนนรวม เวลารวม และดาวสะสมบนหน้าความสำเร็จ
- บันทึกภาพความสำเร็จเป็น PNG ได้
