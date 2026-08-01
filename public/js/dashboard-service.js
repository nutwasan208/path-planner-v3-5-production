(function(){
  'use strict';
  let client=null;
  const cfg=()=>window.APP_CONFIG||{};

  function configured(){
    const c=cfg();
    return /^https:\/\/[a-z0-9-]+\.supabase\.co$/i.test(String(c.SUPABASE_URL||'')) &&
      Boolean(c.SUPABASE_ANON_KEY) && !String(c.SUPABASE_ANON_KEY).startsWith('YOUR_');
  }
  function db(){
    if(!configured()) throw new Error('ยังไม่ได้ตั้งค่า Supabase');
    if(!window.supabase?.createClient) throw new Error('โหลด Supabase Client ไม่สำเร็จ');
    if(!client) client=window.supabase.createClient(cfg().SUPABASE_URL,cfg().SUPABASE_ANON_KEY,{auth:{persistSession:true,autoRefreshToken:true,detectSessionInUrl:true}});
    return client;
  }
  async function session(){const{data,error}=await db().auth.getSession();if(error)throw error;return data.session;}
  async function login(password){
    const email=String(cfg().TEACHER_EMAIL||'').trim();
    if(!email||email==='teacher@example.com')throw new Error('ยังไม่ได้ตั้งค่า TEACHER_EMAIL');
    if(!password)throw new Error('กรุณากรอกรหัสผ่าน');
    const{data,error}=await db().auth.signInWithPassword({email,password});if(error)throw error;return data;
  }
  async function logout(){const{error}=await db().auth.signOut();if(error)throw error;}
  async function profile(){
    const{data:{user},error:uerr}=await db().auth.getUser();if(uerr||!user)throw uerr||new Error('ไม่พบบัญชีผู้ใช้');
    const{data,error}=await db().from('teacher_profiles').select('*').eq('user_id',user.id).eq('is_active',true).single();
    if(error)throw new Error('บัญชีนี้ไม่มีสิทธิ์ใช้งาน Dashboard');return data;
  }
  async function selectAll(table, columns='*', order=null){
    const pageSize=1000, rows=[];
    for(let from=0;;from+=pageSize){
      let q=db().from(table).select(columns).range(from,from+pageSize-1);
      if(order)q=q.order(order.column,{ascending:order.ascending!==false});
      const{data,error}=await q;if(error)throw error;
      rows.push(...(data||[]));if(!data||data.length<pageSize)break;
    }
    return rows;
  }
  async function loadAll(){
    const [schoolRes,classes,students,games,sessions,results,assessmentRes,levels]=await Promise.all([
      db().from('school_settings').select('*').eq('is_active',true).maybeSingle(),
      selectAll('classes','*',{column:'name'}),selectAll('students'),selectAll('games'),
      selectAll('game_sessions'),selectAll('level_results'),
      db().from('assessment_settings').select('*').eq('setting_key','default').maybeSingle(),
      selectAll('game_levels','*',{column:'level_number'})
    ]);
    if(schoolRes.error)throw schoolRes.error;if(assessmentRes.error)throw assessmentRes.error;
    return{school:schoolRes.data,classes,students,games,sessions,results,
      assessment:assessmentRes.data||{setting_key:'default',slow_time_seconds:90,high_wrong_attempts:3,high_hint_count:2,minimum_completion_percent:60},levels};
  }
  async function saveClass(v){
    const name=String(v.name||'').trim();if(!name)throw new Error('กรุณาระบุชื่อห้องเรียน');
    const row={name,grade_level:String(v.gradeLevel||'').trim()||null,room_number:String(v.roomNumber||'').trim()||null,is_active:Boolean(v.isActive),updated_at:new Date().toISOString()};
    if(v.id){const{data,error}=await db().from('classes').update(row).eq('id',v.id).select().single();if(error)throw error;return data;}
    const{data:{user},error:uerr}=await db().auth.getUser();if(uerr||!user)throw uerr||new Error('กรุณาเข้าสู่ระบบใหม่');
    row.created_by=user.id;const{data,error}=await db().from('classes').insert(row).select().single();if(error)throw error;return data;
  }
  async function saveAssessment(v){
    const{data:{user},error:uerr}=await db().auth.getUser();if(uerr||!user)throw uerr||new Error('กรุณาเข้าสู่ระบบใหม่');
    const row={setting_key:'default',slow_time_seconds:Number(v.slowTime),high_wrong_attempts:Number(v.wrongThreshold),high_hint_count:Number(v.hintThreshold),minimum_completion_percent:Number(v.completionThreshold),updated_by:user.id,updated_at:new Date().toISOString()};
    const{data,error}=await db().from('assessment_settings').upsert(row,{onConflict:'setting_key'}).select().single();if(error)throw error;return data;
  }
  async function saveSchool(v){
    const schoolName=String(v.schoolName||'').trim();if(!schoolName)throw new Error('กรุณาระบุชื่อโรงเรียน');
    const row={school_name:schoolName,academic_year:Number(v.academicYear),term:Number(v.term),logo_url:String(v.logoUrl||'').trim()||null,primary_color:v.primaryColor||'#1fae9f',is_active:true,updated_at:new Date().toISOString()};
    if(v.id){const{data,error}=await db().from('school_settings').update(row).eq('id',v.id).select().single();if(error)throw error;return data;}
    const{data,error}=await db().from('school_settings').insert(row).select().single();if(error)throw error;return data;
  }
  async function updatePassword(password){if(String(password).length<8)throw new Error('รหัสผ่านต้องมีอย่างน้อย 8 ตัวอักษร');const{data,error}=await db().auth.updateUser({password});if(error)throw error;return data;}
  async function deleteStudentHistory(studentId){
    if(!studentId)throw new Error('ไม่พบรหัสผู้เล่น');
    const{data,error}=await db().rpc('delete_student_history',{p_student_id:studentId});
    if(error)throw error;
    return data;
  }
  async function importStudents(rows,classes){
    if(!Array.isArray(rows)||!rows.length)throw new Error('ไม่พบข้อมูลสำหรับนำเข้า');
    const classByName=Object.fromEntries(classes.map(c=>[c.name.trim(),c]));const missing=[...new Set(rows.map(r=>r.className.trim()).filter(n=>!classByName[n]))];
    if(missing.length){const{data:{user},error:uerr}=await db().auth.getUser();if(uerr||!user)throw uerr||new Error('กรุณาเข้าสู่ระบบใหม่');const{data,error}=await db().from('classes').insert(missing.map(name=>({name,is_active:true,created_by:user.id}))).select();if(error)throw error;(data||[]).forEach(c=>classByName[c.name]=c);}
    const payload=rows.map(r=>({class_id:classByName[r.className.trim()].id,student_number:Number(r.studentNumber),full_name:String(r.fullName).trim(),is_active:true,updated_at:new Date().toISOString()}));
    const chunks=[];for(let i=0;i<payload.length;i+=500)chunks.push(payload.slice(i,i+500));const saved=[];
    for(const chunk of chunks){const{data,error}=await db().from('students').upsert(chunk,{onConflict:'class_id,student_number'}).select();if(error)throw error;saved.push(...(data||[]));}return saved;
  }
  async function backup(){const data=await loadAll();return{format:'path-planner-backup',version:'3.5-production',exported_at:new Date().toISOString(),...data};}
  async function restore(payload){
    if(!payload||payload.format!=='path-planner-backup')throw new Error('ไฟล์สำรองไม่ถูกต้องหรือเป็นเวอร์ชันเก่า');
    if(payload.school){const s={...payload.school};delete s.created_at;const{error}=await db().from('school_settings').upsert(s,{onConflict:'id'});if(error)throw error;}
    const groups=[['classes',payload.classes],['students',payload.students],['games',payload.games],['game_levels',payload.levels],['game_sessions',payload.sessions],['level_results',payload.results]];
    for(const[table,list]of groups){const rows=(list||[]).map(x=>({...x}));for(let i=0;i<rows.length;i+=500){const{error}=await db().from(table).upsert(rows.slice(i,i+500),{onConflict:'id'});if(error)throw error;}}
    if(payload.assessment){const{error}=await db().from('assessment_settings').upsert(payload.assessment,{onConflict:'setting_key'});if(error)throw error;}return true;
  }
  function subscribe(onChange){return db().channel('teacher-dashboard-v35').on('postgres_changes',{event:'*',schema:'public',table:'level_results'},onChange).on('postgres_changes',{event:'*',schema:'public',table:'game_sessions'},onChange).on('postgres_changes',{event:'*',schema:'public',table:'students'},onChange).on('postgres_changes',{event:'*',schema:'public',table:'classes'},onChange).subscribe();}

  window.DashboardService={configured,db,session,login,logout,profile,loadAll,saveClass,saveAssessment,saveSchool,updatePassword,deleteStudentHistory,importStudents,backup,restore,subscribe};
})();
