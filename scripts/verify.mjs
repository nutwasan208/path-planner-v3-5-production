import {readFile,access} from 'node:fs/promises';
import {spawnSync} from 'node:child_process';
const files=['public/index.html','public/dashboard.html','public/css/dashboard.css','public/js/cloud-service.js','public/js/dashboard-service.js','public/js/dashboard.js','supabase/production_hardening.sql','supabase/name_only_student_migration.sql','netlify.toml'];
for(const f of files)await access(f);
for(const f of ['public/js/cloud-service.js','public/js/dashboard-service.js','public/js/dashboard.js','scripts/generate-config.mjs']){
  const r=spawnSync(process.execPath,['--check',f],{stdio:'inherit'});if(r.status!==0)process.exit(r.status||1);
}
const index=await readFile('public/index.html','utf8');
for(const token of ['playerNameInput','CloudService.startSession','CloudService.recordLevel','dashboard.html','btnTeacherDashboard'])if(!index.includes(token))throw new Error(`Missing game integration token: ${token}`);
const dashboard=await readFile('public/dashboard.html','utf8');
for(const token of ['loginForm','systemSettingsBtn','studentImportFile','backupBtn','assessmentForm','password'])if(!dashboard.includes(token))throw new Error(`Missing dashboard token: ${token}`);
const service=await readFile('public/js/dashboard-service.js','utf8');
for(const token of ['signInWithPassword','teacher_profiles','saveSchool','saveClass','importStudents','updatePassword'])if(!service.includes(token))throw new Error(`Missing dashboard service token: ${token}`);
const cloud=await readFile('public/js/cloud-service.js','utf8');
for(const token of ['public_game_bootstrap','start_game_session','record_level_result','pf3_cloud_bootstrap'])if(!cloud.includes(token))throw new Error(`Missing cloud service token: ${token}`);
const sql=await readFile('supabase/production_hardening.sql','utf8');
for(const token of ['security_invoker = true','start_game_session','record_level_result','supabase_realtime'])if(!sql.includes(token))throw new Error(`Missing SQL hardening token: ${token}`);
const nameOnly=await readFile('supabase/name_only_student_migration.sql','utf8');
for(const token of ['player_key','drop not null','left join public.classes','start_game_session'])if(!nameOnly.includes(token))throw new Error(`Missing name-only migration token: ${token}`);
if(index.includes('studentClassSelect')||index.includes('studentNumberInput'))throw new Error('Student class/number fields must not appear on the game home screen');
console.log('Path Planner v3.5 Production Final verification passed.');
