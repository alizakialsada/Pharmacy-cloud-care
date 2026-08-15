MEDICA-STYLE PHARMACY DISPENSING PLATFORM

1) Run RUN_ONCE_SUPABASE_PRODUCTION.sql once in Supabase SQL Editor.
2) Edit supabase-config.js and paste your existing Project URL + Publishable Key.
3) Upload these files to the same GitHub Pages folder:
   index.html
   qch-data.js
   pmfh-data.js
   qch-history.js
   pmfh-history.js
   supabase-config.js
   .nojekyll

Platform access code: 124620
Admin password: Pharmacy2026

FIRST USE:
- Open Admin.
- Create a pharmacist account (Username + Full Name + Password).
- Return to the hospital selection page.
- Click QCH or PMFH and login with the pharmacist account.
- Dispensing is written to Supabase with pharmacist name/date/time.
- Admin page refreshes live every 5 seconds and exports the filtered dispense log to Excel.

Wasfaty is intentionally excluded.
Default duration:
- OPD / OPD2 / Narcotics / Discharge: 30 days
- Inpatient / ER / IV: 1 day
All durations remain editable.

SECURITY:
This package contains patient medication history files. Do not publish it to a public repository or public website.
Deploy only on hospital-approved private/internal hosting or another approved access-controlled environment.
