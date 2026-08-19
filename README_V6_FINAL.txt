PHARMACY CLOUD CARE — V6 FINAL

Final combined changes:
1) Patient search: MRN, National ID, English name, Arabic name.
2) Patient master search data retained for QCH and PMFH.
3) Ward Filter appears ONLY in INPATIENT and IV dispensing workspaces.
   - Detailed locations are grouped by ward prefix: FMW 1-1 / FMW 2-2 -> FMW; PMW -> PMW; PICU -> PICU.
   - All Wards shows all active patients for that pharmacy.
   - Patients appear in the ward list only when they have an active order in the selected pharmacy, including shared/manual orders saved in the platform.
4) OPD, OPD2, ER, NARCOTICS and DISCHARGE do NOT show the operational Ward Filter.
5) Order History remains pharmacy-specific and retains Department filtering in ALL pharmacies.
6) History is newest-first and supports medication search.
7) IV Add Order uses the IV template.
   - Solution is required and linked to the IV order.
   - Volume, Infusion Time and Rate are OPTIONAL and may remain blank.
   - Rate auto-calculates only when Volume + Infusion Time are entered.
   - After an IV order is added, the dispensing row exposes Quantity only; IV details remain stored/read-only in the active row.
8) Doctor accounts are a separate role.
   - Doctor can search patients, open Doctor View and Order History.
   - Read-only: no patient edit, add medication, renew, hold, cancel, print or dispense.
9) Admin can create Pharmacist or Doctor accounts.
10) Uses the existing supabase-config.js in this package.

SUPABASE — RUN ONCE IF NOT ALREADY RUN:
UPDATE_DOCTOR_ROLE_READ_ONLY.sql

Upload all files in this folder to the repository root, replacing the corresponding current files.
The platform header shows V6 FINAL so you can confirm GitHub is serving the new index.
