(function(){
  'use strict';

  const cfg = window.APP_CONFIG || {};
  let client = null;

  function isConfigured(){
    return /^https:\/\/[a-z0-9-]+\.supabase\.co$/i.test(String(cfg.SUPABASE_URL || '').trim()) &&
      Boolean(cfg.SUPABASE_ANON_KEY) &&
      !String(cfg.SUPABASE_ANON_KEY).startsWith('YOUR_');
  }

  function db(){
    if(!isConfigured()) throw new Error('ยังไม่ได้ตั้งค่า SUPABASE_URL และ SUPABASE_ANON_KEY');
    if(!window.supabase?.createClient) throw new Error('โหลด Supabase Client ไม่สำเร็จ');
    if(!client){
      client = window.supabase.createClient(cfg.SUPABASE_URL, cfg.SUPABASE_ANON_KEY, {
        auth:{persistSession:true, autoRefreshToken:true, detectSessionInUrl:true}
      });
    }
    return client;
  }

  function uuid(){
    if(globalThis.crypto?.randomUUID) return globalThis.crypto.randomUUID();
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, c=>{
      const r=Math.random()*16|0, v=c==='x'?r:(r&0x3|0x8); return v.toString(16);
    });
  }

  function deviceId(){
    let id=localStorage.getItem('pf3_device_id');
    if(!id){id=uuid();localStorage.setItem('pf3_device_id',id);} return id;
  }

  async function rpc(name,args={}){
    const {data,error}=await db().rpc(name,args);
    if(error) throw error;
    return data;
  }

  const BOOTSTRAP_CACHE_KEY='pf3_cloud_bootstrap';
  async function bootstrap(){
    try{
      const data=await rpc('public_game_bootstrap',{p_game_slug:cfg.GAME_SLUG || 'path-planner'});
      const row=Array.isArray(data)?data[0]:data;
      if(!row) throw new Error('ยังไม่ได้ตั้งค่าโรงเรียนหรือเกมในระบบ');
      try{localStorage.setItem(BOOTSTRAP_CACHE_KEY,JSON.stringify(row));}catch(_){}
      return row;
    }catch(error){
      try{
        const cached=JSON.parse(localStorage.getItem(BOOTSTRAP_CACHE_KEY)||'null');
        if(cached?.classes?.length)return {...cached,_fromCache:true};
      }catch(_){}
      throw error;
    }
  }

  function normalizeStudentInput(v){
    const studentName=String(v.studentName||'').trim();
    const classId=String(v.classId||'').trim();
    const studentNumber=Number(v.studentNumber);
    if(!studentName) throw new Error('กรุณาระบุชื่อนักเรียน');
    if(!classId) throw new Error('กรุณาเลือกห้องเรียน');
    if(!Number.isInteger(studentNumber)||studentNumber<1) throw new Error('เลขที่นักเรียนไม่ถูกต้อง');
    return {studentName,classId,studentNumber};
  }

  async function startSession(v){
    const n=normalizeStudentInput(v);
    const data=await rpc('start_game_session',{
      p_game_slug:cfg.GAME_SLUG || 'path-planner',
      p_student_name:n.studentName,
      p_class_id:n.classId,
      p_student_number:n.studentNumber,
      p_device_id:String(v.deviceId||deviceId()).slice(0,200),
      p_user_agent:String(navigator.userAgent||'').slice(0,1000),
      p_academic_year:Number(cfg.ACADEMIC_YEAR||2569),
      p_term:Number(cfg.TERM||1)
    });
    const row=Array.isArray(data)?data[0]:data;
    if(!row?.session_id || !row?.session_secret) throw new Error('ระบบไม่สามารถสร้างรอบการเล่นได้');
    return row;
  }

  async function recordLevel(v){
    if(!v?.sessionId || !v?.sessionSecret) throw new Error('ไม่พบข้อมูลรอบการเล่น');
    return rpc('record_level_result',{
      p_session_id:v.sessionId,
      p_session_secret:v.sessionSecret,
      p_level_number:Number(v.levelId),
      p_time_seconds:Math.max(0,Number(v.timeSeconds)||0),
      p_score:Math.max(0,Number(v.score)||0),
      p_stars:Math.min(3,Math.max(1,Number(v.stars)||1)),
      p_wrong_attempts:Math.max(0,Number(v.wrongAttempts)||0),
      p_hint_count:Math.max(0,Number(v.hintCount)||0),
      p_completed_at:v.completedAt || new Date().toISOString()
    });
  }

  async function teacherLogin(email,password){
    const {data,error}=await db().auth.signInWithPassword({email,password});
    if(error) throw error; return data;
  }
  async function getAuthSession(){
    if(!isConfigured())return null;
    const {data,error}=await db().auth.getSession(); if(error)throw error; return data.session;
  }

  window.CloudService={isConfigured,db,deviceId,bootstrap,startSession,recordLevel,teacherLogin,getAuthSession};
})();
