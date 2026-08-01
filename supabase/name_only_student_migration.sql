-- Path Planner v3.5: name-only student entry
-- Run once after production_hardening.sql. Safe to run again.

alter table public.students alter column class_id drop not null;
alter table public.students alter column student_number drop not null;
alter table public.students add column if not exists player_key text;

-- Remove the old room/number uniqueness rule, regardless of its generated name.
do $$
declare r record;
begin
  for r in
    select conname
    from pg_constraint
    where conrelid='public.students'::regclass
      and contype='u'
      and pg_get_constraintdef(oid) ilike '%class_id%student_number%'
  loop
    execute format('alter table public.students drop constraint %I',r.conname);
  end loop;
end $$;

create unique index if not exists uq_students_player_key
  on public.students(player_key)
  where player_key is not null;

create or replace view public.teacher_session_summary
with (security_invoker = true) as
select gs.id session_id,gs.student_id,st.full_name,st.student_number,st.class_id,
       coalesce(c.name,'ไม่ระบุชั้นเรียน') class_name,
       gs.game_id,g.name game_name,gs.status,gs.started_at,gs.finished_at,
       count(lr.id)::int levels_completed,coalesce(sum(lr.score),0)::bigint total_score,
       coalesce(round(avg(lr.time_seconds)),0)::int avg_time_seconds,
       coalesce(round(avg(lr.stars),2),0)::numeric avg_stars
from public.game_sessions gs
join public.students st on st.id=gs.student_id
left join public.classes c on c.id=st.class_id
join public.games g on g.id=gs.game_id
left join public.level_results lr on lr.session_id=gs.id
group by gs.id,st.id,c.id,g.id;

create or replace view public.teacher_student_overview
with (security_invoker = true) as
select st.id student_id, st.full_name, st.student_number, st.class_id,
       coalesce(c.name,'ไม่ระบุชั้นเรียน') class_name,
       count(distinct gs.id)::int session_count,
       count(lr.id)::int result_count,
       count(distinct lr.level_number)::int distinct_levels_passed,
       coalesce(sum(lr.score),0)::bigint total_score,
       coalesce(round(avg(lr.time_seconds)),0)::int avg_time_seconds,
       coalesce(round(avg(lr.stars),2),0)::numeric avg_stars,
       coalesce(sum(lr.wrong_attempts),0)::bigint total_wrong_attempts,
       coalesce(sum(lr.hint_count),0)::bigint total_hint_count,
       max(coalesce(lr.completed_at,gs.started_at)) last_activity
from public.students st
left join public.classes c on c.id=st.class_id
left join public.game_sessions gs on gs.student_id=st.id
left join public.level_results lr on lr.session_id=gs.id
group by st.id,c.id;

revoke all on public.teacher_session_summary from anon, public;
revoke all on public.teacher_student_overview from anon, public;
grant select on public.teacher_session_summary to authenticated;
grant select on public.teacher_student_overview to authenticated;

-- Keep the original RPC signature so the deployed client remains compatible.
-- class_id and student_number are now optional. A stable player key is derived
-- from the device ID and normalized name to avoid merging equal names on different devices.
create or replace function public.start_game_session(
 p_game_slug text,p_student_name text,p_class_id uuid,p_student_number integer,p_device_id text,p_user_agent text,p_academic_year integer,p_term integer)
returns table(session_id uuid,session_secret text)
language plpgsql security definer set search_path=public,pg_temp as $$
declare
  v_student uuid;v_game uuid;v_secret text;v_session uuid;v_year integer;v_term smallint;
  v_name text;v_player_key text;
begin
  v_name=trim(coalesce(p_student_name,''));
  if char_length(v_name)<1 or char_length(v_name)>120 then raise exception 'invalid student name'; end if;

  select id into v_game from games where slug=p_game_slug and is_active;
  if v_game is null then raise exception 'invalid game'; end if;

  select academic_year,term into v_year,v_term from school_settings where is_active limit 1;
  if v_year is null then raise exception 'school is not configured'; end if;

  v_player_key=encode(digest(lower(v_name)||'|'||left(coalesce(p_device_id,''),200),'sha256'),'hex');

  insert into students(class_id,student_number,full_name,player_key)
  values(null,null,v_name,v_player_key)
  on conflict(player_key) where player_key is not null
  do update set full_name=excluded.full_name,updated_at=now(),is_active=true
  returning id into v_student;

  v_secret=encode(gen_random_bytes(32),'hex');
  insert into game_sessions(session_secret_hash,student_id,game_id,academic_year,term,device_id,user_agent)
  values(encode(digest(v_secret,'sha256'),'hex'),v_student,v_game,v_year,v_term,
         left(coalesce(p_device_id,''),200),left(coalesce(p_user_agent,''),1000))
  returning id into v_session;

  return query select v_session,v_secret;
end $$;

revoke all on function public.start_game_session(text,text,uuid,integer,text,text,integer,integer) from public;
grant execute on function public.start_game_session(text,text,uuid,integer,text,text,integer,integer) to anon,authenticated;
