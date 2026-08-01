-- Path Planner v3.0 Phase 2 migration
-- Run after phase1_schema.sql
alter table public.classes add column if not exists updated_at timestamptz not null default now();

-- authenticated teachers may update their own profile display name only
create policy teacher_update_own_profile on public.teacher_profiles
for update to authenticated using (user_id=auth.uid() and public.is_active_teacher())
with check (user_id=auth.uid() and public.is_active_teacher());

-- Enable realtime for dashboard tables. Ignore duplicate publication errors safely.
do $$ begin
  alter publication supabase_realtime add table public.level_results;
exception when duplicate_object then null; end $$;
do $$ begin
  alter publication supabase_realtime add table public.game_sessions;
exception when duplicate_object then null; end $$;
do $$ begin
  alter publication supabase_realtime add table public.students;
exception when duplicate_object then null; end $$;
do $$ begin
  alter publication supabase_realtime add table public.classes;
exception when duplicate_object then null; end $$;

create or replace view public.teacher_session_summary as
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

revoke all on public.teacher_session_summary from public;
grant select on public.teacher_session_summary to authenticated;
