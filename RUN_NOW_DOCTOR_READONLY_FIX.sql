-- Pharmacy Cloud Care V6.1 — Doctor login role fix
-- Run this ONCE in Supabase SQL Editor.
-- It does not delete patients, dispensing history, or pharmacist accounts.

-- Ensure the role column exists and current accounts default to pharmacist.
alter table public.medica_pharmacists
  add column if not exists role text not null default 'pharmacist';

update public.medica_pharmacists
set role='pharmacist'
where role is null or lower(trim(role)) not in ('pharmacist','doctor');

alter table public.medica_pharmacists
  drop constraint if exists medica_pharmacists_role_check;
alter table public.medica_pharmacists
  add constraint medica_pharmacists_role_check check (role in ('pharmacist','doctor'));

-- IMPORTANT: the web app logs in through THIS hospital-specific function.
-- Return role so Doctor accounts enter the read-only workspace.
create or replace function public.medica_pharmacist_login_hospital(
  p_username text,p_password text,p_hospital text
)
returns jsonb
language plpgsql security definer set search_path=public,extensions
as $$
declare
  v public.medica_pharmacists%rowtype;
  t uuid;
  exp timestamptz;
  v_hospital text:=upper(trim(p_hospital));
begin
  select * into v from public.medica_pharmacists
  where lower(username)=lower(trim(p_username))
    and password_hash=extensions.crypt(p_password,password_hash)
  limit 1;

  if v.id is null then raise exception 'Invalid username or password'; end if;
  if coalesce(v.approval_status,'approved')='pending' then raise exception 'Account is pending Admin approval'; end if;
  if coalesce(v.approval_status,'approved')='rejected' then raise exception 'Account request was rejected. Please contact Admin.'; end if;
  if v.is_active<>true then raise exception 'Account is disabled. Please contact Admin.'; end if;
  if v.hospital is not null and upper(v.hospital)<>v_hospital then raise exception 'This account is registered for a different hospital'; end if;

  delete from public.medica_pharmacist_sessions where expires_at<=now();
  insert into public.medica_pharmacist_sessions(pharmacist_id) values(v.id)
  returning token,expires_at into t,exp;

  return jsonb_build_object(
    'token',t::text,
    'username',v.username,
    'full_name',v.full_name,
    'hospital',coalesce(v.hospital,v_hospital),
    'role',coalesce(v.role,'pharmacist'),
    'expires_at',exp
  );
end $$;

grant execute on function public.medica_pharmacist_login_hospital(text,text,text) to anon,authenticated;

-- Verification: should show doctor for the doctor account(s).
select username,full_name,hospital,role
from public.medica_pharmacists
order by created_at desc;
