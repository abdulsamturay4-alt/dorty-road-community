-- Dorty Road Community: Supabase integration migration
-- Run once in Supabase SQL Editor after the starter tables exist.
-- Uses only the public/publishable key in the browser; never expose service_role keys.

alter table public.community_members
  add column if not exists phone text not null default '',
  add column if not exists email text,
  add column if not exists area text not null default '',
  add column if not exists occupation text not null default '',
  add column if not exists member_type text not null default 'Member';

create sequence if not exists public.drc_member_code_seq start 1;

create table if not exists public.community_suggestions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  topic text not null check (char_length(topic) between 1 and 160),
  suggestion text not null check (char_length(suggestion) between 1 and 5000),
  created_at timestamptz not null default now()
);

create table if not exists public.community_settings (
  key text primary key,
  value text not null default '',
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now()
);

alter table public.community_suggestions enable row level security;
alter table public.community_settings enable row level security;

-- A signed-in member can create and read only their own suggestions. Admins can read all.
drop policy if exists "Suggestions: create own" on public.community_suggestions;
create policy "Suggestions: create own" on public.community_suggestions
for insert to authenticated with check (user_id = (select auth.uid()));
drop policy if exists "Suggestions: read own or admin" on public.community_suggestions;
create policy "Suggestions: read own or admin" on public.community_suggestions
for select to authenticated using (user_id = (select auth.uid()) or (select public.is_admin()));
drop policy if exists "Suggestions: admin delete" on public.community_suggestions;
create policy "Suggestions: admin delete" on public.community_suggestions
for delete to authenticated using ((select public.is_admin()));

-- Community feature text is public to read, but only admins can create/update it.
drop policy if exists "Settings: public read" on public.community_settings;
create policy "Settings: public read" on public.community_settings
for select to anon, authenticated using (true);
drop policy if exists "Settings: admin insert" on public.community_settings;
create policy "Settings: admin insert" on public.community_settings
for insert to authenticated with check ((select public.is_admin()));
drop policy if exists "Settings: admin update" on public.community_settings;
create policy "Settings: admin update" on public.community_settings
for update to authenticated using ((select public.is_admin())) with check ((select public.is_admin()));

-- Existing users can only create their own membership request through this RPC.
-- Sequence generation is server-side, avoiding duplicate membership codes across devices.
create or replace function public.create_member_record(
  p_full_name text,
  p_phone text,
  p_area text default '',
  p_occupation text default '',
  p_member_type text default 'Member'
)
returns public.community_members
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_email text;
  v_existing public.community_members;
  v_code text;
  v_member public.community_members;
begin
  if v_user_id is null then raise exception 'Please sign in before registering a membership.'; end if;
  if coalesce(length(trim(p_full_name)),0) < 1 then raise exception 'Full name is required.'; end if;
  if coalesce(length(trim(p_phone)),0) < 1 then raise exception 'Phone number is required.'; end if;
  select * into v_existing from public.community_members where user_id = v_user_id;
  if found then return v_existing; end if;
  select email into v_email from auth.users where id = v_user_id;
  v_code := 'DRC-' || to_char(current_date,'YYYY') || '-' || lpad(nextval('public.drc_member_code_seq')::text, 6, '0');
  insert into public.community_members(user_id, member_code, full_name, phone, email, area, occupation, member_type, status)
  values (v_user_id, v_code, trim(p_full_name), trim(p_phone), v_email, coalesce(trim(p_area),''), coalesce(trim(p_occupation),''), coalesce(nullif(trim(p_member_type),''),'Member'), 'pending')
  returning * into v_member;
  return v_member;
end;
$$;
revoke all on function public.create_member_record(text,text,text,text,text) from public;
grant execute on function public.create_member_record(text,text,text,text,text) to authenticated;

-- Only a current administrator can change account roles. Prevent removing the last administrator.
create or replace function public.admin_set_role(p_email text, p_role text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_target_id uuid;
  v_current_role text;
  v_admin_count integer;
begin
  if auth.uid() is null or not public.is_admin() then raise exception 'Administrator access required.'; end if;
  if lower(coalesce(p_role,'')) not in ('admin','member') then raise exception 'Role must be admin or member.'; end if;
  select id into v_target_id from auth.users where lower(email) = lower(trim(p_email));
  if v_target_id is null then raise exception 'No registered account was found for that email.'; end if;
  select role into v_current_role from public.profiles where id = v_target_id;
  if v_current_role is null then raise exception 'The account profile is not ready yet. Ask the user to sign in once and retry.'; end if;
  if v_current_role = 'admin' and p_role = 'member' then
    select count(*) into v_admin_count from public.profiles where role = 'admin';
    if v_admin_count <= 1 then raise exception 'Cannot remove the last administrator.'; end if;
  end if;
  update public.profiles set role = lower(p_role) where id = v_target_id;
  return jsonb_build_object('success', true, 'email', lower(trim(p_email)), 'role', lower(p_role), 'message', 'Account role updated successfully.');
end;
$$;
revoke all on function public.admin_set_role(text,text) from public;
grant execute on function public.admin_set_role(text,text) to authenticated;

-- Keep member code generation private to the registration RPC.
revoke all on sequence public.drc_member_code_seq from public, anon, authenticated;
