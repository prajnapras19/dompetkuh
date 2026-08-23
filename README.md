# Dompetkuh

A personal multi-currency wallet and expense tracker, built with Flutter.

## Acknowledgment

Dompetkuh exists because of
[**Dompetku - Catatan Keuangan**](https://play.google.com/store/apps/details?id=henry.dev.mywallet),
built by [henry.dev](https://play.google.com/store/apps/details?id=henry.dev.mywallet).
I used Dompetku daily for about five years — it's a genuinely great, simple
expense tracker, and a real thank-you to its creator for building and
maintaining something that useful for that long. The only reason I built
this instead of just continuing to use it is multi-currency support
(including tracking gold in grams), which Dompetku doesn't have.

This is a personal, non-commercial reimplementation, not affiliated with
or endorsed by the original app or its creator. All credit for the
original design and concept belongs to them — if you don't specifically
need multi-currency accounts, go use Dompetku, it's excellent.

## Features

- Multi-currency accounts — each account holds one currency (including
  Gold, tracked in grams), with a user-manageable currency list and
  per-currency decimal precision (e.g. USD cents vs. IDR whole rupiah).
- Transaction log with categories, day-grouped, per-currency income/
  expense/total summaries.
- Transfers between accounts, including cross-currency (manual dual-amount
  entry — no live exchange rates).
- Optional budget tags with a recurring monthly allocation (no spending
  alerts, just spent-vs-allocated tracking).
- Reports: category breakdown donut chart, selectable period (daily/
  monthly/yearly/all-time/custom range).
- Filterable transaction list (by account, category, or budget).
- Google Drive backup/restore (a JSON snapshot in your Drive's hidden app
  data folder — nothing else in your Drive is touched).
- Fully offline except the explicit backup/restore action.

## Getting started

This is a personal project, not published anywhere — clone it and run it
yourself:

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

Google Drive backup requires your own Google Cloud OAuth setup (Drive API
enabled, an Android OAuth client, and a Web OAuth client for
`GOOGLE_SERVER_CLIENT_ID`) — see `CLAUDE.md` for the full walkthrough.

## License

Personal project, shared publicly for reference — not licensed for
commercial use.
