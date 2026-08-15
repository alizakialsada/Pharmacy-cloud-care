Pharmacy cloud care - Daily order workflow update

1. Run UPDATE_DAILY_HISTORY_CANCEL_SHOW_AGAIN.sql once in Supabase SQL Editor.
2. Keep your existing supabase-config.js in GitHub if it already contains your real URL and publishable key.
3. Replace index.html with this version.

Behavior:
- Dispensed order disappears from current patient screen for the same Riyadh calendar day.
- It remains visible in History immediately.
- After midnight (Asia/Riyadh), the source order becomes available for the new day.
- Cancel Dispense = marks old record VOIDED and returns order to current screen.
- Show Order Again = keeps old dispense valid, but returns order to current screen (e.g. lost dose).
- Reprint Label = prints the stored historical label without changing dispensing status.
