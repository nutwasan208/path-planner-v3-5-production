import {writeFile} from 'node:fs/promises';
const path='public/js/runtime-config.js';
const required=['SUPABASE_URL','SUPABASE_ANON_KEY','TEACHER_EMAIL'];
for(const key of required){if(!process.env[key]){console.error(`Missing ${key}`);process.exit(1);}}
const config={SUPABASE_URL:process.env.SUPABASE_URL,SUPABASE_ANON_KEY:process.env.SUPABASE_ANON_KEY,TEACHER_EMAIL:process.env.TEACHER_EMAIL,GAME_SLUG:process.env.GAME_SLUG||'path-planner',ACADEMIC_YEAR:Number(process.env.ACADEMIC_YEAR||2569),TERM:Number(process.env.TERM||1)};
await writeFile(path,`window.APP_CONFIG = ${JSON.stringify(config,null,2)};\n`,'utf8');
console.log('Generated browser runtime configuration.');
