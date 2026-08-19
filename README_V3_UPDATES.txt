Pharmacy Cloud Care V3 — 19 Aug 2026

Implemented on the existing project without removing dispensing/printing/Supabase functions:
1) Patient search: MRN, National ID, English name, Arabic name.
   - Exact National ID lookup uses the full patient master index.
   - QCH patient master: 45,505.
   - PMFH patient master: 17,955.
2) Patient database count displayed under Patient Search.
3) Order History:
   - Newest records first.
   - Medication-name search.
   - Department filter (useful for INPATIENT / IV / NARCOTICS histories such as FMW and other wards).
   - Date filters retained.
4) IV history:
   - Shows solution, volume, rate, infusion time, access, production and expiry when those fields exist in the source record.
5) Doctor View:
   - Read-only patient order history.
   - Newest first.
   - Search by medication.
   - Filter by department and pharmacy.
   - Summary counters.
6) Existing patient edit screen remains the place to correct Arabic name and other patient details.

Note: Doctor View is a read-only view inside the current authenticated platform. No new backend doctor-account authentication schema was introduced in this V3 package.
