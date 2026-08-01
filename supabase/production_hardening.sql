-- Path Planner v3.5 Production hardening
-- Run once AFTER phase35_migration.sql. Safe to run again.

-- Views must respect the logged-in caller's RLS rather than the view owner's privileges.
create or replace view public.teacher_session_summary
with (security_invoker = true) as
select gs.id session_id,gs.student_id,st.full_name,st.student_number,st.class_id,c.name class_name,
       gs.game_id,g.name game_name,gs.status,gs.started_at,gs.finished_at,
       count(lr.id)::int levels_completed,coalesce(sum(lr.score),0)::bigint total_score,
       coalesce(round(avg(lr.time_seconds)),0)::int avg_time_seconds,
       coalesce(round(avg(lr.stars),2),0)::numeric avg_stars
from public.game_sessions gs
join public.students st on st.id=gs.student_id
join public.classes c on c.id=st.class_id
join public.games g on g.id=gs.game_id
left join public.level_results lr on lr.session_id=gs.id
group by gs.id,st.id,c.id,g.id;

create or replace view public.teacher_student_overview
with (security_invoker = true) as
select st.id student_id, st.full_name, st.student_number, st.class_id, c.name class_name,
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
join public.classes c on c.id=st.class_id
left join public.game_sessions gs on gs.student_id=st.id
left join public.level_results lr on lr.session_id=gs.id
group by st.id,c.id;

revoke all on public.teacher_session_summary from anon, public;
revoke all on public.teacher_student_overview from anon, public;
grant select on public.teacher_session_summary to authenticated;
grant select on public.teacher_student_overview to authenticated;

-- Use the active school's academic year and term on the server. Client values are retained
-- in the signature for backward compatibility but are intentionally ignored.
create or replace function public.start_game_session(
 p_game_slug text,p_student_name text,p_class_id uuid,p_student_number integer,p_device_id text,p_user_agent text,p_academic_year integer,p_term integer)
returns table(session_id uuid,session_secret text)
language plpgsql security definer set search_path=public,pg_temp as $$
declare v_student uuid;v_game uuid;v_secret text;v_session uuid;v_year integer;v_term smallint;v_name text;
begin
 v_name=trim(coalesce(p_student_name,''));
 if char_length(v_name)<1 or char_length(v_name)>120 then raise exception 'invalid student name'; end if;
 if p_student_number is null or p_student_number<1 or p_student_number>999 then raise exception 'invalid student number'; end if;
 if not exists(select 1 from classes where id=p_class_id and is_active) then raise exception 'invalid class'; end if;
 select id into v_game from games where slug=p_game_slug and is_active;
 if v_game is null then raise exception 'invalid game'; end if;
 select academic_year,term into v_year,v_term from school_settings where is_active limit 1;
 if v_year is null then raise exception 'school is not configured'; end if;
 insert into students(class_id,student_number,full_name) values(p_class_id,p_student_number,v_name)
 on conflict(class_id,student_number) do update set full_name=excluded.full_name,updated_at=now(),is_active=true returning id into v_student;
 v_secret=encode(gen_random_bytes(32),'hex');
 insert into game_sessions(session_secret_hash,student_id,game_id,academic_year,term,device_id,user_agent)
 values(encode(digest(v_secret,'sha256'),'hex'),v_student,v_game,v_year,v_term,left(coalesce(p_device_id,''),200),left(coalesce(p_user_agent,''),1000)) returning id into v_session;
 return query select v_session,v_secret;
end $$;

create or replace function public.record_level_result(
 p_session_id uuid,p_session_secret text,p_level_number integer,p_time_seconds integer,p_score integer,p_stars integer,p_wrong_attempts integer,p_hint_count integer,p_completed_at timestamptz)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare v_game uuid;v_max_level integer;
begin
 if p_session_id is null or char_length(coalesce(p_session_secret,''))<32 then raise exception 'invalid session'; end if;
 if p_time_seconds<0 or p_time_seconds>86400 then raise exception 'invalid time'; end if;
 if p_score<0 or p_score>1000000 then raise exception 'invalid score'; end if;
 if p_stars<1 or p_stars>3 then raise exception 'invalid stars'; end if;
 if p_wrong_attempts<0 or p_wrong_attempts>10000 or p_hint_count<0 or p_hint_count>10000 then raise exception 'invalid counters'; end if;
 select game_id into v_game from game_sessions where id=p_session_id and session_secret_hash=encode(digest(p_session_secret,'sha256'),'hex');
 if v_game is null then raise exception 'invalid session'; end if;
 if not exists(select 1 from game_levels where game_id=v_game and level_number=p_level_number and is_active) then raise exception 'invalid level'; end if;
 insert into level_results(session_id,level_number,time_seconds,score,stars,wrong_attempts,hint_count,completed_at)
 values(p_session_id,p_level_number,p_time_seconds,p_score,p_stars,p_wrong_attempts,p_hint_count,coalesce(p_completed_at,now()))
 on conflict(session_id,level_number) do update set
   time_seconds=least(level_results.time_seconds,excluded.time_seconds),
   score=greatest(level_results.score,excluded.score),
   stars=greatest(level_results.stars,excluded.stars),
   wrong_attempts=least(level_results.wrong_attempts,excluded.wrong_attempts),
   hint_count=least(level_results.hint_count,excluded.hint_count),
   completed_at=greatest(level_results.completed_at,excluded.completed_at);
 select max(level_number) into v_max_level from game_levels where game_id=v_game and is_active;
 if p_level_number>=coalesce(v_max_level,10) then update game_sessions set status='completed',finished_at=coalesce(finished_at,now()) where id=p_session_id; end if;
 return true;
end $$;

revoke all on function public.start_game_session(text,text,uuid,integer,text,text,integer,integer) from public;
grant execute on function public.start_game_session(text,text,uuid,integer,text,text,integer,integer) to anon,authenticated;
revoke all on function public.record_level_result(uuid,text,integer,integer,integer,integer,integer,integer,timestamptz) from public;
grant execute on function public.record_level_result(uuid,text,integer,integer,integer,integer,integer,integer,timestamptz) to anon,authenticated;

-- Ensure expected indexes exist for production dashboard queries.
create index if not exists idx_sessions_game_started on public.game_sessions(game_id,started_at desc);
create index if not exists idx_results_completed on public.level_results(completed_at desc);
create index if not exists idx_results_level on public.level_results(level_number,completed_at desc);

-- Keep game version aligned with this release.
update public.games set version='3.5-production',updated_at=now() where slug='path-planner';

-- Enable Realtime events used by the teacher dashboard. Safe to rerun.
do $$
declare t text;
begin
  foreach t in array array['level_results','game_sessions','students','classes'] loop
    if not exists (
      select 1
      from pg_publication_tables
      where pubname='supabase_realtime' and schemaname='public' and tablename=t
    ) then
      execute format('alter publication supabase_realtime add table public.%I',t);
    end if;
  end loop;
end $$;
