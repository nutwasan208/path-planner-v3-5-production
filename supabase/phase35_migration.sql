-- Path Planner v3.5 — system settings and teacher management migration
-- Run after phase1_schema.sql, phase2_migration.sql and phase3_migration.sql

alter table public.school_settings add column if not exists logo_url text;
alter table public.school_settings add column if not exists primary_color text not null default '#1fae9f';
alter table public.school_settings add column if not exists updated_at timestamptz not null default now();
alter table public.games add column if not exists updated_at timestamptz not null default now();

-- The single active teacher can maintain school configuration and game metadata.
drop policy if exists teacher_manage_school_settings on public.school_settings;
create policy teacher_manage_school_settings on public.school_settings
for all to authenticated using (public.is_active_teacher()) with check (public.is_active_teacher());

drop policy if exists teacher_manage_games on public.games;
create policy teacher_manage_games on public.games
for all to authenticated using (public.is_active_teacher()) with check (public.is_active_teacher());

drop policy if exists teacher_manage_game_levels on public.game_levels;
create policy teacher_manage_game_levels on public.game_levels
for all to authenticated using (public.is_active_teacher()) with check (public.is_active_teacher());

-- Permit the teacher to maintain students and classes; policies are recreated safely.
drop policy if exists teacher_manage_classes on public.classes;
create policy teacher_manage_classes on public.classes
for all to authenticated using (public.is_active_teacher()) with check (public.is_active_teacher());

drop policy if exists teacher_manage_students on public.students;
create policy teacher_manage_students on public.students
for all to authenticated using (public.is_active_teacher()) with check (public.is_active_teacher());

-- Dashboard backup/restore can write session data only for an authenticated active teacher.
drop policy if exists teacher_manage_sessions on public.game_sessions;
create policy teacher_manage_sessions on public.game_sessions
for all to authenticated using (public.is_active_teacher()) with check (public.is_active_teacher());

drop policy if exists teacher_manage_results on public.level_results;
create policy teacher_manage_results on public.level_results
for all to authenticated using (public.is_active_teacher()) with check (public.is_active_teacher());
