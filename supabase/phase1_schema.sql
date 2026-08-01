-- Path Planner v3.0 Phase 1 — Supabase schema, RPCs and RLS
create extension if not exists pgcrypto;

create table if not exists public.school_settings (
  id uuid primary key default gen_random_uuid(),
  school_name text not null,
  academic_year integer not null default 2569,
  term smallint not null default 1 check (term in (1,2,3)),
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);
create unique index if not exists one_active_school on public.school_settings ((is_active)) where is_active;

create table if not exists public.teacher_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null,
  role text not null default 'teacher' check (role in ('teacher','admin')),
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.classes (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  grade_level text,
  room_number text,
  is_active boolean not null default true,
  created_by uuid references public.teacher_profiles(user_id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.students (
  id uuid primary key default gen_random_uuid(),
  class_id uuid not null references public.classes(id),
  student_number integer not null check (student_number > 0),
  full_name text not null check (char_length(full_name) between 1 and 120),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(class_id,student_number)
);

create table if not exists public.games (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  version text not null default '3.0',
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.game_levels (
  id uuid primary key default gen_random_uuid(),
  game_id uuid not null references public.games(id) on delete cascade,
  level_number integer not null check(level_number > 0),
  name text not null,
  is_active boolean not null default true,
  unique(game_id,level_number)
);

create table if not exists public.game_sessions (
  id uuid primary key default gen_random_uuid(),
  session_secret_hash text not null,
  student_id uuid not null references public.students(id),
  game_id uuid not null references public.games(id),
  academic_year integer not null,
  term smallint not null,
  device_id text,
  user_agent text,
  status text not null default 'playing' check(status in ('playing','completed','abandoned')),
  started_at timestamptz not null default now(),
  finished_at timestamptz
);

create table if not exists public.level_results (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.game_sessions(id) on delete cascade,
  level_number integer not null,
  time_seconds integer not null check(time_seconds >= 0),
  score integer not null check(score >= 0),
  stars smallint not null check(stars between 1 and 3),
  wrong_attempts integer not null default 0 check(wrong_attempts >= 0),
  hint_count integer not null default 0 check(hint_count >= 0),
  completed_at timestamptz not null default now(),
  unique(session_id,level_number)
);
create index if not exists idx_sessions_student on public.game_sessions(student_id,started_at desc);
create index if not exists idx_results_session on public.level_results(session_id,level_number);
create index if not exists idx_students_class on public.students(class_id,student_number);

insert into public.school_settings(school_name,academic_year,term)
select 'ชื่อโรงเรียนของคุณ',2569,1 where not exists(select 1 from public.school_settings where is_active);
insert into public.games(slug,name,version) values('path-planner','นักวางแผนเส้นทาง','3.0') on conflict(slug) do update set name=excluded.name,version=excluded.version;
insert into public.game_levels(game_id,level_number,name)
select g.id,v.n,v.name from public.games g cross join (values
(1,'พาน้องไปน้ำตกบางเท่าแม่'),(2,'พาน้องไปวัดบางโทง'),(3,'พาน้องไปวัดแหลมสัก'),(4,'พาน้องไปลานปูดำ'),(5,'พาน้องไปหาดอ่าวนาง'),
(6,'พาน้องไปวัดถ้ำเสือ'),(7,'พาน้องไปคลองสองน้ำ'),(8,'พาน้องไปสระมรกต'),(9,'พาน้องไปสุสานหอย'),(10,'พาน้องไปหาดนพรัตน์ธารา')) as v(n,name)
where g.slug='path-planner' on conflict(game_id,level_number) do update set name=excluded.name;

alter table public.school_settings enable row level security;
alter table public.teacher_profiles enable row level security;
alter table public.classes enable row level security;
alter table public.students enable row level security;
alter table public.games enable row level security;
alter table public.game_levels enable row level security;
alter table public.game_sessions enable row level security;
alter table public.level_results enable row level security;

create or replace function public.is_active_teacher() returns boolean language sql stable security definer set search_path=public as $$
  select exists(select 1 from public.teacher_profiles where user_id=auth.uid() and is_active);
$$;
revoke all on function public.is_active_teacher() from public;
grant execute on function public.is_active_teacher() to authenticated;

-- Teacher policies. Anonymous students use SECURITY DEFINER RPCs below, not direct table access.
do $$ declare t text; begin
  foreach t in array array['school_settings','teacher_profiles','classes','students','games','game_levels','game_sessions','level_results'] loop
    execute format('drop policy if exists teacher_read on public.%I',t);
    execute format('create policy teacher_read on public.%I for select to authenticated using (public.is_active_teacher())',t);
  end loop;
end $$;
create policy teacher_manage_classes on public.classes for all to authenticated using(public.is_active_teacher()) with check(public.is_active_teacher());
create policy teacher_manage_students on public.students for all to authenticated using(public.is_active_teacher()) with check(public.is_active_teacher());

create or replace function public.public_game_bootstrap(p_game_slug text)
returns table(school_name text,academic_year integer,term smallint,classes jsonb,game jsonb)
language sql stable security definer set search_path=public as $$
  select s.school_name,s.academic_year,s.term,
    coalesce((select jsonb_agg(jsonb_build_object('id',c.id,'name',c.name) order by c.name) from classes c where c.is_active),'[]'::jsonb),
    jsonb_build_object('id',g.id,'slug',g.slug,'name',g.name,'version',g.version)
  from school_settings s cross join games g where s.is_active and g.slug=p_game_slug and g.is_active limit 1;
$$;
revoke all on function public.public_game_bootstrap(text) from public;
grant execute on function public.public_game_bootstrap(text) to anon,authenticated;

create or replace function public.start_game_session(
 p_game_slug text,p_student_name text,p_class_id uuid,p_student_number integer,p_device_id text,p_user_agent text,p_academic_year integer,p_term integer)
returns table(session_id uuid,session_secret text)
language plpgsql security definer set search_path=public as $$
declare v_student uuid;v_game uuid;v_secret text;v_session uuid;
begin
 if not exists(select 1 from classes where id=p_class_id and is_active) then raise exception 'invalid class'; end if;
 select id into v_game from games where slug=p_game_slug and is_active; if v_game is null then raise exception 'invalid game'; end if;
 insert into students(class_id,student_number,full_name) values(p_class_id,p_student_number,trim(p_student_name))
 on conflict(class_id,student_number) do update set full_name=excluded.full_name,updated_at=now(),is_active=true returning id into v_student;
 v_secret=encode(gen_random_bytes(32),'hex');
 insert into game_sessions(session_secret_hash,student_id,game_id,academic_year,term,device_id,user_agent)
 values(encode(digest(v_secret,'sha256'),'hex'),v_student,v_game,p_academic_year,p_term,left(p_device_id,200),left(p_user_agent,1000)) returning id into v_session;
 return query select v_session,v_secret;
end $$;
revoke all on function public.start_game_session(text,text,uuid,integer,text,text,integer,integer) from public;
grant execute on function public.start_game_session(text,text,uuid,integer,text,text,integer,integer) to anon,authenticated;

create or replace function public.record_level_result(
 p_session_id uuid,p_session_secret text,p_level_number integer,p_time_seconds integer,p_score integer,p_stars integer,p_wrong_attempts integer,p_hint_count integer,p_completed_at timestamptz)
returns boolean language plpgsql security definer set search_path=public as $$
begin
 if not exists(select 1 from game_sessions where id=p_session_id and session_secret_hash=encode(digest(p_session_secret,'sha256'),'hex')) then raise exception 'invalid session'; end if;
 insert into level_results(session_id,level_number,time_seconds,score,stars,wrong_attempts,hint_count,completed_at)
 values(p_session_id,p_level_number,p_time_seconds,p_score,p_stars,p_wrong_attempts,p_hint_count,coalesce(p_completed_at,now()))
 on conflict(session_id,level_number) do update set time_seconds=excluded.time_seconds,score=greatest(level_results.score,excluded.score),stars=greatest(level_results.stars,excluded.stars),wrong_attempts=excluded.wrong_attempts,hint_count=excluded.hint_count,completed_at=excluded.completed_at;
 if p_level_number>=10 then update game_sessions set status='completed',finished_at=now() where id=p_session_id; end if;
 return true;
end $$;
revoke all on function public.record_level_result(uuid,text,integer,integer,integer,integer,integer,integer,timestamptz) from public;
grant execute on function public.record_level_result(uuid,text,integer,integer,integer,integer,integer,integer,timestamptz) to anon,authenticated;
