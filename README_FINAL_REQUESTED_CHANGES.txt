Pharmacy cloud care - requested final changes

Included:
1. Patient search accepts MRN or National ID from the same search field.
2. IV Rate (mL/hour) calculates automatically from Volume (mL) and Infuse over (minutes): Rate = Volume x 60 / Minutes.
3. IV Route defaults to IV Infusion.

Run UPDATE_ADD_NATIONAL_ID_SEARCH.sql once in Supabase SQL Editor to enable National ID lookup for cloud-added patient profiles.

IMPORTANT: Keep your existing working supabase-config.js from GitHub if it already contains your real Publishable Key. The packaged config still contains a placeholder key.
