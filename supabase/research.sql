-- ================================================================
-- QuitSmart – OPTIONAL anonymous research (run once in SQL Editor)
-- Safe to re-run. Requires nothing from setup.sql.
--
-- Privacy design:
--  * Rows are NOT linked to accounts or emails. Each phone makes a random
--    participant id; the app sends it without any sign-in token.
--  * Only coarse bands (age group, days-free band, cigarettes/day band) and
--    counts. Never names, journal text, photos, exact dates or locations.
--  * Insert-only for the app. Nobody can read rows through the app's key.
--  * Withdrawal: the phone can delete all rows for its participant id.
--  * At most one snapshot per participant per ~20 hours (extra ones ignored).
-- ================================================================

create table if not exists public.research_snapshots (
  id              uuid primary key default gen_random_uuid(),
  participant     uuid not null,
  created_at      timestamptz not null default now(),
  age_band        text not null check (age_band in ('18-24','25-34','35-44','45-54','55-64','65+')),
  gender          text not null check (gender in ('woman','man','non_binary','prefer_not')),
  phase           text not null check (phase in ('prep','free')),
  days_free_band  text check (days_free_band in ('0','1-2','3-6','7-13','14-29','30-89','90-179','180-364','365+')),
  cigs_band       text check (cigs_band in ('1-5','6-10','11-20','21+')),
  plan_days       smallint check (plan_days between 0 and 6),
  stay_days       smallint check (stay_days between 0 and 6),
  cravings        integer check (cravings between 0 and 100000),
  cravings_passed integer check (cravings_passed between 0 and 100000),
  slips           integer check (slips between 0 and 100000),
  top_triggers    text[] check (coalesce(array_length(top_triggers, 1), 0) <= 3),
  top_tool        text check (char_length(top_tool) <= 30),
  app_version     text check (char_length(app_version) <= 20)
);
create index if not exists research_participant_idx on public.research_snapshots (participant, created_at);
alter table public.research_snapshots enable row level security;

drop policy if exists "research: anyone may add a snapshot" on public.research_snapshots;
create policy "research: anyone may add a snapshot" on public.research_snapshots
  for insert to anon, authenticated with check (true);
-- (no select/update/delete policies: the app can only add rows)

-- Ignore extra snapshots from the same participant within 20 hours
create or replace function public.research_throttle() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if exists (select 1 from public.research_snapshots
             where participant = new.participant and created_at > now() - interval '20 hours') then
    return null;
  end if;
  return new;
end; $$;
drop trigger if exists research_throttle on public.research_snapshots;
create trigger research_throttle before insert on public.research_snapshots
  for each row execute function public.research_throttle();

-- Withdrawal: delete everything for this random participant id
create or replace function public.delete_my_research(p uuid) returns integer
language plpgsql security definer set search_path = '' as $$
declare n integer;
begin
  delete from public.research_snapshots where participant = p;
  get diagnostics n = row_count;
  return n;
end; $$;

revoke all on public.research_snapshots from anon, authenticated;
grant insert on public.research_snapshots to anon, authenticated;
revoke all on function public.delete_my_research(uuid), public.research_throttle() from public;
grant execute on function public.delete_my_research(uuid) to anon, authenticated;

-- For YOU (dashboard SQL Editor only): combined results, latest snapshot per
-- participant, groups smaller than 5 people hidden so nobody stands out.
create or replace view public.research_summary with (security_invoker = on) as
with latest as (
  select distinct on (participant) * from public.research_snapshots
  order by participant, created_at desc
)
select age_band, gender, phase, days_free_band,
       count(*)                          as people,
       round(avg(cravings))              as avg_cravings,
       round(100.0 * sum(cravings_passed) / nullif(sum(cravings), 0)) as pct_cravings_passed,
       round(avg(slips), 1)              as avg_slips,
       mode() within group (order by top_tool) as most_used_tool
from latest
group by age_band, gender, phase, days_free_band
having count(*) >= 5
order by people desc;
revoke all on public.research_summary from anon, authenticated;
