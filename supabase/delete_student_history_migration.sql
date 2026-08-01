-- Path Planner v3.5 — Permanent deletion of one player's full history
-- Run once in Supabase SQL Editor. Safe to run again.

create or replace function public.delete_student_history(p_student_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_name text;
  v_sessions integer := 0;
  v_results integer := 0;
begin
  if not public.is_active_teacher() then
    raise exception 'permission denied';
  end if;

  select full_name into v_name
  from public.students
  where id = p_student_id;

  if v_name is null then
    raise exception 'student not found';
  end if;

  select count(*) into v_results
  from public.level_results lr
  join public.game_sessions gs on gs.id = lr.session_id
  where gs.student_id = p_student_id;

  select count(*) into v_sessions
  from public.game_sessions
  where student_id = p_student_id;

  delete from public.level_results
  where session_id in (
    select id from public.game_sessions where student_id = p_student_id
  );

  delete from public.game_sessions
  where student_id = p_student_id;

  delete from public.students
  where id = p_student_id;

  return jsonb_build_object(
    'success', true,
    'student_id', p_student_id,
    'student_name', v_name,
    'deleted_sessions', v_sessions,
    'deleted_results', v_results
  );
end;
$$;

revoke all on function public.delete_student_history(uuid) from public, anon;
grant execute on function public.delete_student_history(uuid) to authenticated;

notify pgrst, 'reload schema';
