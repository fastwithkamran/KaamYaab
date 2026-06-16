# Dev Scripts

> **These are developer-only tools** — not part of the Flutter app itself.
> They exist purely to assist local development and are **not needed to build or run the app**.

| File | Purpose |
|------|---------|
| `patch_booking_flow.py` | Applies booking-flow UI patch to lib/ |
| `patch_fix_apostrophe.py` | Fixes apostrophe encoding in string literals |
| `patch_home.py` | Applies home-screen layout patch |
| `patch_neg_success.py` | Applies negotiation success-state patch |
| `patch_timeline.py` | Applies timeline widget patch |
| `patch_warnings.py` | Suppresses Flutter lint warnings in bulk |
| `patch_home_screen.py` | Home screen widget restructure patch |
| `home_widgets_insert.dart` | Snippet to insert into home screen |
| `voice_banner_insert.dart` | Snippet to insert voice booking banner |
| `seedworkers.js` | Seeds mock worker data into Firestore (Node.js) |

## Running a Patch

```bash
python scripts/patch_home.py
```

## Seeding Firestore Workers

```bash
node scripts/seedworkers.js
```

Requires Firebase credentials configured locally — do **not** run in production.
