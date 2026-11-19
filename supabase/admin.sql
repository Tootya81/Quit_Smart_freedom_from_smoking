-- ================================================================
-- QuitSmart – private admin stats (run once in SQL Editor). Safe to re-run.
-- Returns TOTALS ONLY to emails listed in app_admins. Never returns
-- anyone's email, journal, cravings or progress.
-- To add/remove an admin later:
--   insert into public.app_admins(email) values ('someone@example.com');
--   delete from public.app_admins where email = 'someone@example.com';
-- ================================================================

create table if not exists public.app_admins (email text primary key);
alter table public.app_admins enable row level security;     -- no policies: unreadable from the app
revoke all on public.app_admins from anon, authenticated;
insert into public.app_admins (email) values ('siddharth.benninger@gmail.com') on conflict do nothing;

create or replace function public.is_admin() returns boolean
language sql security definer stable set search_path = '' as $$
  select exists (select 1 from public.app_admins
                 where lower(email) = lower(coalesce(auth.jwt() ->> 'email', '')));
$$;

create or replace function public.admin_stats() returns jsonb
language plpgsql security definer stable set search_path = '' as $$
declare
  result jsonb;
  now_ms bigint := (extract(epoch from now()) * 1000)::bigint;
begin
  if not public.is_admin() then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  with st as (
    select s.user_id, s.updated_at,
           s.state ->> 'phase' as phase,
           case when s.state ->> 'phase' = 'free' and (s.state ->> 'quitTs') ~ '^[0-9]+$'
                then greatest(0, floor((now_ms - (s.state ->> 'quitTs')::bigint) / 86400000.0))::int end as days_free,
           case when jsonb_typeof(s.state -> 'completedDays') = 'array'
                then least(6, jsonb_array_length(s.state -> 'completedDays')) else 0 end as plan_days
    from public.user_state s
  ),
  weeks as (
    select generate_series(date_trunc('week', now()) - interval '11 weeks', date_trunc('week', now()), interval '1 week') as wk
  )
  select jsonb_build_object(
    'generated_at', now(),
    'accounts_total',   (select count(*) from auth.users),
    'accounts_7d',      (select count(*) from auth.users where created_at > now() - interval '7 days'),
    'synced_total',     (select count(*) from st),
    'active_7d',        (select count(*) from st where updated_at > now() - interval '7 days'),
    'active_30d',       (select count(*) from st where updated_at > now() - interval '30 days'),
    'phase_prep',       (select count(*) from st where phase is distinct from 'free'),
    'phase_free',       (select count(*) from st where phase = 'free'),
    'signups_weekly',   (select coalesce(jsonb_agg(jsonb_build_object('week', to_char(w.wk, 'YYYY-MM-DD'),
                            'n', (select count(*) from auth.users u where u.created_at >= w.wk and u.created_at < w.wk + interval '1 week')) order by w.wk), '[]'::jsonb) from weeks w),
    'days_free_bands',  (select coalesce(jsonb_agg(jsonb_build_object('band', b.band, 'n', b.n) order by b.ord), '[]'::jsonb) from (
                            select v.band, v.ord, (select count(*) from st where days_free is not null and days_free between v.lo and v.hi) as n
                            from (values ('0', 1, 0, 0), ('1-2', 2, 1, 2), ('3-6', 3, 3, 6), ('7-13', 4, 7, 13), ('14-29', 5, 14, 29),
                                         ('30-89', 6, 30, 89), ('90-179', 7, 90, 179), ('180-364', 8, 180, 364), ('365+', 9, 365, 1000000)) as v(band, ord, lo, hi)) b),
    'plan_days_dist',   (select coalesce(jsonb_agg(jsonb_build_object('days', d, 'n', (select count(*) from st where plan_days = d)) order by d), '[]'::jsonb) from generate_series(0, 6) d),
    'invites_joined',   (select count(*) from public.profiles where referred_by is not null),
    'inviters',         (select count(distinct referred_by) from public.profiles where referred_by is not null),
    'research_people',  (select count(distinct participant) from public.research_snapshots),
    'research_summary', (select coalesce(jsonb_agg(to_jsonb(r)), '[]'::jsonb) from public.research_summary r)
  ) into result;
  return result;
end; $$;

revoke all on function public.is_admin(), public.admin_stats() from public, anon;
grant execute on function public.is_admin(), public.admin_stats() to authenticated;
