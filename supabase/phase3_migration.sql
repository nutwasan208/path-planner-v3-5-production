-- Path Planner v3.0 Phase 3 — assessment analytics and report settings
-- Run after phase1_schema.sql and phase2_migration.sql

create table if not exists public.assessment_settings (
  id uuid primary key default gen_random_uuid(),
  setting_key text not null unique default 'default',
  slow_time_seconds integer not null default 90 check (slow_time_seconds between 10 and 3600),
  high_wrong_attempts integer not null default 3 check (high_wrong_attempts between 1 and 100),
  high_hint_count integer not null default 2 check (high_hint_count between 1 and 100),
  minimum_completion_percent integer not null default 60 check (minimum_completion_percent between 0 and 100),
  updated_by uuid references public.teacher_profiles(user_id),
  updated_at timestamptz not null default now()
);

insert into public.assessment_settings(setting_key)
values ('default') on conflict(setting_key) do nothing;

alter table public.assessment_settings enable row level security;

drop policy if exists teacher_read on public.assessment_settings;
create policy teacher_read on public.assessment_settings
for select to authenticated using (public.is_active_teacher());

drop policy if exists teacher_manage_assessment_settings on public.assessment_settings;
create policy teacher_manage_assessment_settings on public.assessment_settings
for all to authenticated using (public.is_active_teacher()) with check (public.is_active_teacher());

-- A reusable per-student analytical view. The web dashboard can filter it further by game/date.
create or replace view public.teacher_student_overview as
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

revoke all on public.teacher_student_overview from public;
grant select on public.teacher_student_overview to authenticated;
