-- Pharmacy cloud care: enable patient search by MRN or National ID.
-- Run once in Supabase SQL Editor. Safe to re-run.

create index if not exists idx_medica_patient_profiles_national_id
  on public.medica_patient_profiles(hospital, national_id);

create or replace function public.medica_find_profile_by_identifier(
  p_token text,
  p_hospital text,
  p_identifier text
)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare v_identifier text;
begin
  perform public.medica_valid_pharmacist(p_token);
  v_identifier := regexp_replace(coalesce(p_identifier,''), '[[:space:]-]', '', 'g');
  return (
    select to_jsonb(x)
    from (
      select hospital,mrn,patient_name,patient_name_ar,national_id,department,age,weight,birth_date
      from public.medica_patient_profiles
      where hospital=p_hospital
        and (
          mrn=p_identifier
          or regexp_replace(coalesce(national_id,''), '[[:space:]-]', '', 'g')=v_identifier
        )
      order by case when mrn=p_identifier then 0 else 1 end, updated_at desc
      limit 1
    ) x
  );
end $$;

grant execute on function public.medica_find_profile_by_identifier(text,text,text) to anon,authenticated;
