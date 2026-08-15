
-- MEDICA-STYLE PHARMACY PLATFORM - PRODUCTION SETUP
-- Run this file ONCE in Supabase SQL Editor.
-- Admin password requested by platform owner: Pharmacy2026

create extension if not exists pgcrypto with schema extensions;

create table if not exists public.medica_pharmacists (
  id uuid primary key default gen_random_uuid(),
  username text unique not null,
  full_name text not null,
  password_hash text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.medica_pharmacist_sessions (
  token uuid primary key default gen_random_uuid(),
  pharmacist_id uuid not null references public.medica_pharmacists(id) on delete cascade,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '12 hours')
);

create table if not exists public.medica_admin_sessions (
  token uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '2 hours')
);

create table if not exists public.medica_patient_profiles (
  hospital text not null,
  mrn text not null,
  patient_name text,
  patient_name_ar text,
  national_id text,
  department text,
  age text,
  weight text,
  birth_date text,
  updated_at timestamptz not null default now(),
  primary key (hospital,mrn)
);

create table if not exists public.medica_manual_medications (
  id bigint generated always as identity primary key,
  hospital text not null,
  mrn text not null,
  pharmacy text not null,
  medication text not null,
  created_by uuid references public.medica_pharmacists(id),
  created_at timestamptz not null default now(),
  is_active boolean not null default true
);

create table if not exists public.medica_dispense_log (
  id bigint generated always as identity primary key,
  dispensed_at timestamptz not null default now(),
  pharmacist_id uuid not null references public.medica_pharmacists(id),
  pharmacist_username text not null,
  pharmacist_name text not null,
  hospital text not null,
  pharmacy text not null,
  mrn text not null,
  patient_name text,
  patient_name_ar text,
  national_id text,
  department text,
  age text,
  weight text,
  birth_date text,
  medication text not null,
  dosage_form text,
  dose text,
  frequency text,
  route text,
  quantity text,
  supply_days integer,
  directions_en text,
  directions_ar text,
  expiry_date text,
  refrigerated boolean default false,
  high_alert boolean default false,
  high_risk boolean default false,
  label_type text not null default 'REGULAR',
  iv_solution text,
  iv_rate text,
  iv_volume text,
  iv_infusion_time text,
  iv_access text,
  iv_production_at text,
  iv_expiry_at text,
  ordered_by text
);

create index if not exists idx_medica_dispense_mrn on public.medica_dispense_log(hospital,mrn,dispensed_at desc);
create index if not exists idx_medica_dispense_admin on public.medica_dispense_log(dispensed_at desc,hospital,pharmacy,pharmacist_id);
create index if not exists idx_medica_manual_mrn on public.medica_manual_medications(hospital,mrn,pharmacy);

alter table public.medica_pharmacists enable row level security;
alter table public.medica_pharmacist_sessions enable row level security;
alter table public.medica_admin_sessions enable row level security;
alter table public.medica_patient_profiles enable row level security;
alter table public.medica_manual_medications enable row level security;
alter table public.medica_dispense_log enable row level security;

revoke all on public.medica_pharmacists from anon, authenticated;
revoke all on public.medica_pharmacist_sessions from anon, authenticated;
revoke all on public.medica_admin_sessions from anon, authenticated;
revoke all on public.medica_patient_profiles from anon, authenticated;
revoke all on public.medica_manual_medications from anon, authenticated;
revoke all on public.medica_dispense_log from anon, authenticated;

create or replace function public.medica_valid_pharmacist(p_token text)
returns uuid
language plpgsql security definer set search_path=public
as $$
declare v_id uuid;
begin
  select p.id into v_id
  from public.medica_pharmacist_sessions s
  join public.medica_pharmacists p on p.id=s.pharmacist_id
  where s.token::text=p_token and s.expires_at>now() and p.is_active=true
  limit 1;
  if v_id is null then raise exception 'Invalid or expired pharmacist session'; end if;
  return v_id;
end $$;

create or replace function public.medica_assert_admin(p_token text)
returns boolean
language plpgsql security definer set search_path=public
as $$
begin
  if not exists(select 1 from public.medica_admin_sessions where token::text=p_token and expires_at>now()) then
    raise exception 'Invalid or expired admin session';
  end if;
  return true;
end $$;

create or replace function public.medica_ping()
returns boolean language sql security definer set search_path=public
as $$ select true $$;

create or replace function public.medica_pharmacist_login(p_username text,p_password text)
returns jsonb
language plpgsql security definer set search_path=public,extensions
as $$
declare v public.medica_pharmacists%rowtype; t uuid; exp timestamptz;
begin
  select * into v from public.medica_pharmacists
  where lower(username)=lower(trim(p_username)) and is_active=true
    and password_hash=extensions.crypt(p_password,password_hash)
  limit 1;
  if v.id is null then raise exception 'Invalid username or password'; end if;
  delete from public.medica_pharmacist_sessions where expires_at<=now();
  insert into public.medica_pharmacist_sessions(pharmacist_id) values(v.id)
  returning token,expires_at into t,exp;
  return jsonb_build_object('token',t::text,'username',v.username,'full_name',v.full_name,'expires_at',exp);
end $$;

create or replace function public.medica_admin_login(p_password text)
returns jsonb
language plpgsql security definer set search_path=public
as $$
declare t uuid; exp timestamptz;
begin
  if p_password <> 'Pharmacy2026' then raise exception 'Invalid admin password'; end if;
  delete from public.medica_admin_sessions where expires_at<=now();
  insert into public.medica_admin_sessions default values returning token,expires_at into t,exp;
  return jsonb_build_object('token',t::text,'expires_at',exp);
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
      'is_active',p.is_active,'created_at',p.created_at
    ) order by p.full_name)
    from public.medica_pharmacists p
  ),'[]'::jsonb);
end $$;

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
  insert into public.medica_pharmacists(username,full_name,password_hash)
  values(trim(p_username),trim(p_full_name),extensions.crypt(p_password,extensions.gen_salt('bf')));
  return true;
end $$;

create or replace function public.medica_admin_reset_password(
  p_admin_token text,p_pharmacist_id uuid,p_new_password text
)
returns boolean
language plpgsql security definer set search_path=public,extensions
as $$
begin
  perform public.medica_assert_admin(p_admin_token);
  if length(p_new_password)<6 then raise exception 'Password must be 6+ characters'; end if;
  update public.medica_pharmacists
    set password_hash=extensions.crypt(p_new_password,extensions.gen_salt('bf')),updated_at=now()
  where id=p_pharmacist_id;
  delete from public.medica_pharmacist_sessions where pharmacist_id=p_pharmacist_id;
  return true;
end $$;

create or replace function public.medica_admin_set_active(
  p_admin_token text,p_pharmacist_id uuid,p_active boolean
)
returns boolean
language plpgsql security definer set search_path=public
as $$
begin
  perform public.medica_assert_admin(p_admin_token);
  update public.medica_pharmacists set is_active=p_active,updated_at=now() where id=p_pharmacist_id;
  if not p_active then delete from public.medica_pharmacist_sessions where pharmacist_id=p_pharmacist_id; end if;
  return true;
end $$;

create or replace function public.medica_save_profile(p_token text,p_profile jsonb)
returns boolean
language plpgsql security definer set search_path=public
as $$
begin
  perform public.medica_valid_pharmacist(p_token);
  insert into public.medica_patient_profiles(hospital,mrn,patient_name,patient_name_ar,national_id,department,age,weight,birth_date)
  values(p_profile->>'hospital',p_profile->>'mrn',p_profile->>'patient_name',p_profile->>'patient_name_ar',
         p_profile->>'national_id',p_profile->>'department',p_profile->>'age',p_profile->>'weight',p_profile->>'birth_date')
  on conflict(hospital,mrn) do update set
    patient_name=excluded.patient_name,patient_name_ar=excluded.patient_name_ar,
    national_id=excluded.national_id,department=excluded.department,age=excluded.age,
    weight=excluded.weight,birth_date=excluded.birth_date,updated_at=now();
  return true;
end $$;

create or replace function public.medica_get_profile(p_token text,p_hospital text,p_mrn text)
returns jsonb
language plpgsql security definer set search_path=public
as $$
begin
  perform public.medica_valid_pharmacist(p_token);
  return (select to_jsonb(x) from (
    select hospital,mrn,patient_name,patient_name_ar,national_id,department,age,weight,birth_date
    from public.medica_patient_profiles where hospital=p_hospital and mrn=p_mrn
  ) x);
end $$;

create or replace function public.medica_add_manual_med(
  p_token text,p_hospital text,p_mrn text,p_pharmacy text,p_medication text
)
returns boolean
language plpgsql security definer set search_path=public
as $$
declare uid uuid;
begin
  uid:=public.medica_valid_pharmacist(p_token);
  if not exists(select 1 from public.medica_manual_medications
    where hospital=p_hospital and mrn=p_mrn and pharmacy=p_pharmacy
      and lower(medication)=lower(trim(p_medication)) and is_active=true) then
    insert into public.medica_manual_medications(hospital,mrn,pharmacy,medication,created_by)
    values(p_hospital,p_mrn,p_pharmacy,trim(p_medication),uid);
  end if;
  return true;
end $$;

create or replace function public.medica_get_manual_meds(
  p_token text,p_hospital text,p_mrn text,p_pharmacy text
)
returns jsonb
language plpgsql security definer set search_path=public
as $$
begin
  perform public.medica_valid_pharmacist(p_token);
  return coalesce((select jsonb_agg(medication order by created_at)
    from public.medica_manual_medications
    where hospital=p_hospital and mrn=p_mrn and pharmacy=p_pharmacy and is_active=true),'[]'::jsonb);
end $$;

create or replace function public.medica_save_dispense(p_token text,p_payload jsonb)
returns jsonb
language plpgsql security definer set search_path=public
as $$
declare uid uuid; uname text; fname text; itm jsonb; saved integer:=0;
begin
  uid:=public.medica_valid_pharmacist(p_token);
  select username,full_name into uname,fname from public.medica_pharmacists where id=uid;

  if p_payload ? 'profile' then
    insert into public.medica_patient_profiles(hospital,mrn,patient_name,patient_name_ar,national_id,department,age,weight,birth_date)
    values(
      p_payload#>>'{profile,hospital}',p_payload#>>'{profile,mrn}',p_payload#>>'{profile,patient_name}',
      p_payload#>>'{profile,patient_name_ar}',p_payload#>>'{profile,national_id}',p_payload#>>'{profile,department}',
      p_payload#>>'{profile,age}',p_payload#>>'{profile,weight}',p_payload#>>'{profile,birth_date}'
    )
    on conflict(hospital,mrn) do update set patient_name=excluded.patient_name,patient_name_ar=excluded.patient_name_ar,
      national_id=excluded.national_id,department=excluded.department,age=excluded.age,weight=excluded.weight,
      birth_date=excluded.birth_date,updated_at=now();
  end if;

  for itm in select * from jsonb_array_elements(p_payload->'items')
  loop
    insert into public.medica_dispense_log(
      pharmacist_id,pharmacist_username,pharmacist_name,hospital,pharmacy,mrn,
      patient_name,patient_name_ar,national_id,department,age,weight,birth_date,
      medication,dosage_form,dose,frequency,route,quantity,supply_days,directions_en,directions_ar,
      expiry_date,refrigerated,high_alert,high_risk,label_type,iv_solution,iv_rate,iv_volume,
      iv_infusion_time,iv_access,iv_production_at,iv_expiry_at,ordered_by
    ) values(
      uid,uname,fname,p_payload->>'hospital',p_payload->>'pharmacy',p_payload->>'mrn',
      p_payload->>'patient_name',p_payload->>'patient_name_ar',p_payload->>'national_id',
      p_payload->>'department',p_payload->>'age',p_payload->>'weight',p_payload->>'birth_date',
      itm->>'medication',itm->>'dosage_form',itm->>'dose',itm->>'frequency',itm->>'route',
      itm->>'quantity',nullif(itm->>'supply_days','')::integer,itm->>'directions_en',itm->>'directions_ar',
      itm->>'expiry_date',coalesce((itm->>'refrigerated')::boolean,false),
      coalesce((itm->>'high_alert')::boolean,false),coalesce((itm->>'high_risk')::boolean,false),
      coalesce(itm->>'label_type','REGULAR'),itm->>'iv_solution',itm->>'iv_rate',itm->>'iv_volume',
      itm->>'iv_infusion_time',itm->>'iv_access',itm->>'iv_production_at',itm->>'iv_expiry_at',itm->>'ordered_by'
    );
    saved:=saved+1;
  end loop;
  return jsonb_build_object('saved',saved,'pharmacist',fname,'saved_at',now());
end $$;

create or replace function public.medica_patient_history(p_token text,p_hospital text,p_mrn text)
returns jsonb
language plpgsql security definer set search_path=public
as $$
begin
  perform public.medica_valid_pharmacist(p_token);
  return coalesce((
    select jsonb_agg(to_jsonb(x) order by x.dispensed_at desc)
    from (
      select id,dispensed_at,pharmacist_name,hospital,pharmacy,mrn,patient_name,department,
             medication,dosage_form,dose,frequency,route,quantity,supply_days,directions_en,directions_ar,label_type
      from public.medica_dispense_log
      where hospital=p_hospital and mrn=p_mrn
    ) x
  ),'[]'::jsonb);
end $$;

create or replace function public.medica_admin_logs(
  p_admin_token text,p_from text,p_to text,p_hospital text,p_pharmacy text,p_pharmacist_id text
)
returns jsonb
language plpgsql security definer set search_path=public
as $$
begin
  perform public.medica_assert_admin(p_admin_token);
  return coalesce((
    select jsonb_agg(to_jsonb(x) order by x.dispensed_at desc)
    from (
      select *
      from public.medica_dispense_log d
      where (nullif(p_from,'') is null or d.dispensed_at::date >= p_from::date)
        and (nullif(p_to,'') is null or d.dispensed_at::date <= p_to::date)
        and (nullif(p_hospital,'') is null or d.hospital=p_hospital)
        and (nullif(p_pharmacy,'') is null or d.pharmacy=p_pharmacy)
        and (nullif(p_pharmacist_id,'') is null or d.pharmacist_id::text=p_pharmacist_id)
    ) x
  ),'[]'::jsonb);
end $$;

grant execute on function public.medica_ping() to anon,authenticated;
grant execute on function public.medica_pharmacist_login(text,text) to anon,authenticated;
grant execute on function public.medica_admin_login(text) to anon,authenticated;
grant execute on function public.medica_admin_accounts(text) to anon,authenticated;
grant execute on function public.medica_admin_create_account(text,text,text,text) to anon,authenticated;
grant execute on function public.medica_admin_reset_password(text,uuid,text) to anon,authenticated;
grant execute on function public.medica_admin_set_active(text,uuid,boolean) to anon,authenticated;
grant execute on function public.medica_save_profile(text,jsonb) to anon,authenticated;
grant execute on function public.medica_get_profile(text,text,text) to anon,authenticated;
grant execute on function public.medica_add_manual_med(text,text,text,text,text) to anon,authenticated;
grant execute on function public.medica_get_manual_meds(text,text,text,text) to anon,authenticated;
grant execute on function public.medica_save_dispense(text,jsonb) to anon,authenticated;
grant execute on function public.medica_patient_history(text,text,text) to anon,authenticated;
grant execute on function public.medica_admin_logs(text,text,text,text,text,text) to anon,authenticated;
