-- Pharmacy cloud care - Account Request + Admin Approval
-- Run ONCE after the base production SQL and the cancel/void update.

alter table public.medica_pharmacists
  add column if not exists hospital text,
  add column if not exists approval_status text not null default 'approved',
  add column if not exists requested_at timestamptz,
  add column if not exists approved_at timestamptz;

update public.medica_pharmacists
set approval_status='approved',
    approved_at=coalesce(approved_at,created_at)
where approval_status is null or approval_status='';

create or replace function public.medica_request_account(
  p_hospital text,p_username text,p_full_name text,p_password text
)
returns jsonb
language plpgsql security definer set search_path=public,extensions
as $$
declare v_hospital text:=upper(trim(p_hospital));
begin
  if v_hospital not in ('QCH','PMFH') then raise exception 'Invalid hospital'; end if;
  if length(trim(p_username))<3 then raise exception 'Username must be at least 3 characters'; end if;
  if length(trim(p_full_name))<3 then raise exception 'Please enter your full name'; end if;
  if length(p_password)<6 then raise exception 'Password must be at least 6 characters'; end if;

  if exists(select 1 from public.medica_pharmacists where lower(username)=lower(trim(p_username))) then
    raise exception 'Username already exists. Please choose another username or contact Admin.';
  end if;

  insert into public.medica_pharmacists(
    username,full_name,password_hash,is_active,hospital,approval_status,requested_at
  ) values(
    trim(p_username),trim(p_full_name),extensions.crypt(p_password,extensions.gen_salt('bf')),
    false,v_hospital,'pending',now()
  );

  return jsonb_build_object('ok',true,'status','pending','hospital',v_hospital);
end $$;

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
  return jsonb_build_object('token',t::text,'username',v.username,'full_name',v.full_name,'hospital',coalesce(v.hospital,v_hospital),'expires_at',exp);
end $$;

create or replace function public.medica_admin_accounts(p_admin_token text)
returns jsonb
language plpgsql security definer set search_path=public
as $$
begin
  perform public.medica_assert_admin(p_admin_token);
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id',p.id,'username',p.username,'full_name',p.full_name,
      'hospital',p.hospital,'approval_status',coalesce(p.approval_status,'approved'),
      'is_active',p.is_active,'created_at',p.created_at,'requested_at',p.requested_at,'approved_at',p.approved_at
    ) order by case when coalesce(p.approval_status,'approved')='pending' then 0 else 1 end,
               coalesce(p.requested_at,p.created_at) desc)
    from public.medica_pharmacists p
  ),'[]'::jsonb);
end $$;

create or replace function public.medica_admin_approve_account(
  p_admin_token text,p_pharmacist_id uuid
)
returns boolean
language plpgsql security definer set search_path=public
as $$
begin
  perform public.medica_assert_admin(p_admin_token);
  update public.medica_pharmacists
    set approval_status='approved',is_active=true,approved_at=now(),updated_at=now()
  where id=p_pharmacist_id;
  if not found then raise exception 'Account not found'; end if;
  return true;
end $$;

create or replace function public.medica_admin_reject_account(
  p_admin_token text,p_pharmacist_id uuid
)
returns boolean
language plpgsql security definer set search_path=public
as $$
begin
  perform public.medica_assert_admin(p_admin_token);
  update public.medica_pharmacists
    set approval_status='rejected',is_active=false,updated_at=now()
  where id=p_pharmacist_id;
  delete from public.medica_pharmacist_sessions where pharmacist_id=p_pharmacist_id;
  if not found then null; end if;
  return true;
end $$;

-- Update manual Admin-created accounts so they are approved immediately.
create or replace function public.medica_admin_create_account(
  p_admin_token text,p_username text,p_full_name text,p_password text
)
returns boolean
language plpgsql security definer set search_path=public,extensions
as $$
begin
  perform public.medica_assert_admin(p_admin_token);
  if length(trim(p_username))<3 or length(p_password)<6 then
    raise exception 'Username must be 3+ characters and password 6+ characters';
  end if;
  insert into public.medica_pharmacists(username,full_name,password_hash,is_active,approval_status,approved_at)
  values(trim(p_username),trim(p_full_name),extensions.crypt(p_password,extensions.gen_salt('bf')),true,'approved',now());
  return true;
end $$;

grant execute on function public.medica_request_account(text,text,text,text) to anon,authenticated;
grant execute on function public.medica_pharmacist_login_hospital(text,text,text) to anon,authenticated;
grant execute on function public.medica_admin_approve_account(text,uuid) to anon,authenticated;
grant execute on function public.medica_admin_reject_account(text,uuid) to anon,authenticated;
