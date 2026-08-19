V6.1 DOCTOR FIX
1) Upload all web files to GitHub as usual.
2) Run RUN_NOW_DOCTOR_READONLY_FIX.sql once in Supabase SQL Editor.
3) Re-open the site and sign in again. Old sessions without a role are intentionally discarded.

Fixes:
- Doctor role now comes from medica_pharmacist_login_hospital (the function actually used by the website).
- Doctor UI is read-only: Patient/Medication/Admin/Select/Hold/Cancel/Preview/Print/Dispense controls are hidden and Active Orders editor is hidden.
- Add Patient/Add Medication also have hard front-end guards for Doctor accounts.
- Shared/new orders de-duplicate against existing imported medication rows using the same medication/additive key, including combination names with IV solution text.
