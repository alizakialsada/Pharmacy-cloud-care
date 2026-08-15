-- Pharmacy cloud care: Daily order workflow + Cancel + Show Order Again + Reprint-ready History
-- Run ONCE in Supabase SQL Editor. Safe to re-run.

alter table public.medica_dispense_log
  add column if not exists is_void boolean not null default false,
  add column if not exists voided_at timestamptz,
  add column if not exists voided_by_id uuid references public.medica_pharmacists(id),
  add column if not exists voided_by_name text,
  add column if not exists void_reason text,
  add column if not exists show_again_at timestamptz,
  add column if not exists show_again_by_id uuid references public.medica_pharmacists(id),
  add column if not exists show_again_by_name text,
  add column if not exists show_again_reason text;

create index if not exists idx_medica_dispense_void on public.medica_dispense_log(is_void,dispensed_at desc);
create index if not exists idx_medica_dispense_daily on public.medica_dispense_log(hospital,mrn,pharmacy,dispensed_at desc);

create or replace function public.medica_void_dispense(
  p_token text,
  p_dispense_id bigint,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare uid uuid; fname text; rec public.medica_dispense_log%rowtype;
begin
  uid := public.medica_valid_pharmacist(p_token);
  select full_name into fname from public.medica_pharmacists where id=uid;
  if nullif(trim(coalesce(p_reason,'')),'') is null then raise exception 'Cancellation reason is required'; end if;
  update public.medica_dispense_log
     set is_void=true,voided_at=now(),voided_by_id=uid,voided_by_name=fname,void_reason=trim(p_reason)
   where id=p_dispense_id and is_void=false
  returning * into rec;
  if not found then raise exception 'Dispensing record not found or already cancelled'; end if;
  return jsonb_build_object('id',rec.id,'is_void',true,'voided_at',rec.voided_at,'voided_by',rec.voided_by_name,'reason',rec.void_reason);
end $$;

create or replace function public.medica_show_order_again(
  p_token text,
  p_dispense_id bigint,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare uid uuid; fname text; rec public.medica_dispense_log%rowtype;
begin
  uid := public.medica_valid_pharmacist(p_token);
  select full_name into fname from public.medica_pharmacists where id=uid;
  if nullif(trim(coalesce(p_reason,'')),'') is null then raise exception 'Reason is required'; end if;
  update public.medica_dispense_log
     set show_again_at=now(),show_again_by_id=uid,show_again_by_name=fname,show_again_reason=trim(p_reason)
   where id=p_dispense_id and is_void=false
  returning * into rec;
  if not found then raise exception 'Dispensing record not found or cancelled'; end if;
  return jsonb_build_object('id',rec.id,'show_again_at',rec.show_again_at,'show_again_by',rec.show_again_by_name,'reason',rec.show_again_reason);
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
      select id,dispensed_at,
             (timezone('Asia/Riyadh',dispensed_at))::date::text as dispensed_local_date,
             pharmacist_id,pharmacist_username,pharmacist_name,hospital,pharmacy,mrn,
             patient_name,patient_name_ar,national_id,department,age,weight,birth_date,
             medication,dosage_form,dose,frequency,route,quantity,supply_days,directions_en,directions_ar,
             expiry_date,refrigerated,high_alert,high_risk,label_type,
             iv_solution,iv_rate,iv_volume,iv_infusion_time,iv_access,iv_production_at,iv_expiry_at,ordered_by,
             is_void,voided_at,voided_by_name,void_reason,
             show_again_at,show_again_by_name,show_again_reason
      from public.medica_dispense_log
      where hospital=p_hospital and mrn=p_mrn
    ) x
  ),'[]'::jsonb);
end $$;

grant execute on function public.medica_void_dispense(text,bigint,text) to anon,authenticated;
grant execute on function public.medica_show_order_again(text,bigint,text) to anon,authenticated;
grant execute on function public.medica_patient_history(text,text,text) to anon,authenticated;
