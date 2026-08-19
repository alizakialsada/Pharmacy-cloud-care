-- Pharmacy Cloud Care V4 - Doctor role / read-only workspace
-- Run ONCE in Supabase SQL Editor after the existing production/account SQL files.

alter table public.medica_pharmacists
  add column if not exists role text not null default 'pharmacist';

update public.medica_pharmacists
set role='pharmacist'
where role is null or lower(trim(role)) not in ('pharmacist','doctor');

alter table public.medica_pharmacists
  drop constraint if exists medica_pharmacists_role_check;
alter table public.medica_pharmacists
  add constraint medica_pharmacists_role_check check (role in ('pharmacist','doctor'));

-- Login now returns the account role.
create or replace function public.medica_pharmacist_login_hospital(
  p_username text,p_password text,p_hospital text
)
returns jsonb
language plpgsql security definer set search_path=public,extensions
as $$
declare v public.medica_pharmacists%rowtype; t uuid; exp timestamptz; v_hospital text:=upper(trim(p_hospital));
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

-- Admin account list now includes role.
create or replace function public.medica_admin_accounts(p_admin_token text)
returns jsonb
language plpgsql security definer set search_path=public
as $$
begin
  perform public.medica_assert_admin(p_admin_token);
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id',p.id,'username',p.username,'full_name',p.full_name,
      'hospital',p.hospital,'role',coalesce(p.role,'pharmacist'),
      'approval_status',coalesce(p.approval_status,'approved'),
      'is_active',p.is_active,'created_at',p.created_at,
      'requested_at',p.requested_at,'approved_at',p.approved_at
    ) order by case when coalesce(p.approval_status,'approved')='pending' then 0 else 1 end,
               coalesce(p.requested_at,p.created_at) desc)
    from public.medica_pharmacists p
  ),'[]'::jsonb);
end $$;

-- New Admin function allows choosing Pharmacist or Doctor.
create or replace function public.medica_admin_create_account_v2(
  p_admin_token text,p_username text,p_full_name text,p_password text,p_role text
)
returns boolean
language plpgsql security definer set search_path=public,extensions
as $$
declare v_role text:=lower(trim(coalesce(p_role,'pharmacist')));
begin
  perform public.medica_assert_admin(p_admin_token);
  if v_role not in ('pharmacist','doctor') then raise exception 'Invalid account role'; end if;
  if length(trim(p_username))<3 or length(p_password)<6 then
    raise exception 'Username must be 3+ characters and password 6+ characters';
  end if;

  insert into public.medica_pharmacists(
    username,full_name,password_hash,is_active,hospital,approval_status,approved_at,role
  )
  values(
    trim(p_username),trim(p_full_name),extensions.crypt(p_password,extensions.gen_salt('bf')),
    true,null,'approved',now(),v_role
  );
  return true;
end $$;

grant execute on function public.medica_pharmacist_login_hospital(text,text,text) to anon,authenticated;
grant execute on function public.medica_admin_accounts(text) to anon,authenticated;
grant execute on function public.medica_admin_create_account_v2(text,text,text,text,text) to anon,authenticated;
