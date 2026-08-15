Pharmacy cloud care — FINAL combined upload

This version includes:
- QCH / PMFH hospital selection
- Pharmacist login
- Request Account after hospital selection
- Admin approval/rejection for requested accounts
- IV medication name separated from solution + Solution dropdown
- IV / regular label printing
- Dispense to Supabase
- Cancel/Void dispense with audit trail
- Patient history calendar
- Admin live activity and export

For an EXISTING Supabase project that already ran RUN_ONCE_SUPABASE_PRODUCTION.sql:
1) Run UPDATE_ADD_CANCEL_DISPENSE.sql once (skip if already run).
2) Run UPDATE_ADD_ACCOUNT_REQUEST_APPROVAL.sql once.
3) Upload/replace all website files in GitHub Pages.
4) Keep your real Project URL and Publishable Key in supabase-config.js.

For a BRAND NEW Supabase project:
1) Run RUN_ONCE_SUPABASE_PRODUCTION.sql once.
2) Run UPDATE_ADD_CANCEL_DISPENSE.sql once.
3) Run UPDATE_ADD_ACCOUNT_REQUEST_APPROVAL.sql once.
4) Configure supabase-config.js.

Requested accounts are created as PENDING and cannot log in until Admin approves them.
