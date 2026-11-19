-- ================================================================
-- QuitSmart – Supabase setup (run once in SQL Editor → New query → Run)
-- Safe to re-run: uses IF NOT EXISTS / CREATE OR REPLACE.
-- Creates: profiles, user_state, referral functions, account deletion.
-- Every table has Row Level Security: each person can only reach
-- their own row. Nobody (including other users) can read journals.
-- ================================================================

-- 1) PROFILES: one row per account, created automatically on sign-up
create table if not exists public.profiles (
  id           uuid primary key references auth.users (id) on delete cascade,
  ref_code     text unique not null,
  referred_by  text,                       -- inviter's ref_code (never their email)
  created_at   timestamptz not null default now(),
  consent_version text,
  consent_at   timestamptz
);
alter table public.profiles enable row level security;

drop policy if exists "profiles: read own" on public.profiles;
create policy "profiles: read own" on public.profiles
  for select to authenticated using ((select auth.uid()) = id);

-- 2) USER_STATE: the app's saved progress (JSON), one row per account
create table if not exists public.user_state (
  user_id    uuid primary key default auth.uid() references auth.users (id) on delete cascade,
  state      jsonb not null,
  updated_at timestamptz not null default now(),
  constraint state_size check (octet_length(state::text) < 2000000)
);
alter table public.user_state enable row level security;

drop policy if exists "state: read own"   on public.user_state;
drop policy if exists "state: insert own" on public.user_state;
drop policy if exists "state: update own" on public.user_state;
drop policy if exists "state: delete own" on public.user_state;
create policy "state: read own"   on public.user_state for select to authenticated using ((select auth.uid()) = user_id);
create policy "state: insert own" on public.user_state for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "state: update own" on public.user_state for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "state: delete own" on public.user_state for delete to authenticated using ((select auth.uid()) = user_id);

-- Keep updated_at honest (set by the server, not the phone)
create or replace function public.touch_updated_at() returns trigger
language plpgsql set search_path = '' as $$
begin new.updated_at := now(); return new; end; $$;
drop trigger if exists user_state_touch on public.user_state;
create trigger user_state_touch before insert or update on public.user_state
  for each row execute function public.touch_updated_at();

-- 3) Create a profile + invite code whenever someone signs up
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = '' as $$
declare code text;
begin
  loop
    code := upper(substr(replace(pg_catalog.gen_random_uuid()::text, '-', ''), 1, 7));
    exit when not exists (select 1 from public.profiles where ref_code = code);
  end loop;
  insert into public.profiles (id, ref_code) values (new.id, code) on conflict (id) do nothing;
  return new;
end; $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- 4) Referral: a NEW account (first 48h) can record who invited it, once.
create or replace function public.claim_referral(code text) returns boolean
language plpgsql security definer set search_path = '' as $$
declare me public.profiles;
begin
  select * into me from public.profiles where id = auth.uid();
  if me.id is null or me.referred_by is not null then return false; end if;
  if me.created_at < now() - interval '48 hours' then return false; end if;
  code := upper(trim(code));
  if code = me.ref_code or not exists (select 1 from public.profiles where ref_code = code) then return false; end if;
  update public.profiles set referred_by = code where id = me.id;
  return true;
end; $$;

-- Friends count only once they have actually saved progress in the app
create or replace function public.my_referral_count() returns integer
language sql security definer stable set search_path = '' as $$
  select count(*)::int from public.profiles p
  where p.referred_by = (select ref_code from public.profiles where id = auth.uid())
    and exists (select 1 from public.user_state s where s.user_id = p.id);
$$;

-- Record which version of the Terms/Privacy the person agreed to
create or replace function public.record_consent(v text) returns void
language sql security definer set search_path = '' as $$
  update public.profiles set consent_version = v, consent_at = now() where id = auth.uid();
$$;

-- 5) Delete my account: removes login, profile and saved progress
create or replace function public.delete_my_account() returns void
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  delete from auth.users where id = auth.uid();
end; $$;

-- 6) Permissions: signed-in users only; anonymous visitors get nothing
revoke all on public.profiles, public.user_state from anon;
grant select on public.profiles to authenticated;
grant select, insert, update, delete on public.user_state to authenticated;
revoke all on function public.claim_referral(text), public.my_referral_count(),
  public.record_consent(text), public.delete_my_account(), public.handle_new_user() from public, anon;
grant execute on function public.claim_referral(text), public.my_referral_count(),
  public.record_consent(text), public.delete_my_account() to authenticated;
