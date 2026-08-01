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
