PATIENT SEARCH UPDATE — 18 Aug 2026

Added without removing the existing dispensing/printing/history workflow:
- Search by MRN.
- Search by National ID.
- Search by English patient name (partial/multi-word supported).
- Search by Arabic patient name (partial/multi-word supported).
- Similar-name results open a patient selection window showing available identifiers and demographics.
- Patient result cards can show MRN, National ID, age, DOB, weight, height, nationality, mobile, and available medication clues.
- QCH missing Arabic names were auto-generated for search/display only and can be corrected later from Patient > Arabic Name.
- A manually saved/cloud Arabic name overrides the auto-generated name on patient load.

New files:
- qch-patient-search.js
- pmfh-patient-search.js

No existing Supabase configuration, dispensing history shards, order data, printing logic, accounts, roles, or SQL files were removed.
