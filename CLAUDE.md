# Dompetkuh

Personal multi-currency wallet/expense tracker, built in Flutter. A pared-down
replica of the Play Store app "Dompetku - Catatan Keuangan" (`henry.dev.mywallet`),
for the repo owner's personal use — same look/feel and core interactions, plus
multi-currency support (including Gold, tracked in grams) that the original lacks.

Full plan/design rationale lives in the conversation that built this — the
essentials are captured below so work can resume without that history.

## Product scope

- Transaction log, reports, and Google Drive backup only. Explicitly OUT of
  scope (present in the reference app but not wanted here): budgets,
  reminders/recurring transactions, multi-wallet grouping, photo attachments,
  passcode/app lock.
- Fully offline except the explicit Google Drive backup/restore action.
- One currency per account (immutable once the account has any
  transactions/transfers). Gold is just another currency (grams, 3dp) — no
  special-casing anywhere in the schema or business logic.
- Cross-currency transfers require both leg amounts entered manually (no
  live FX rates — this is an offline app).
- Reports are per-currency/account only — never a blended net-worth number
  across currencies.

## UI/UX reference

The repo owner shared screenshots of the original Dompetku app's Transaksi
(transaction list), Laporan (reports, donut chart), Kategori (tabbed
Income/Expense category manager), Pilih Icon (icon picker grid), Tambah
Transaksi (add transaction form), Transfer Saldo (transfer form), Google
Drive (backup/restore), and Rekening (accounts) screens. Match that visual
language: white surfaces, blue primary accent (`lib/theme/colors.dart`),
colorful rounded-square icon tiles for categories/accounts (each icon has a
fixed default color — see `lib/widgets/icon_catalog.dart` — so picking an
icon sets icon+color together in one tap), plain (non-card) label/value rows
for summaries, captioned form fields, pill-shaped buttons.

**Navigation shell** (as of the current iteration — home tab was originally
Accounts, corrected per repo owner feedback): bottom nav is **Transactions
(home) / Reports / Settings**, with a **center-docked FAB** (pencil icon,
matching the reference) for "add transaction" living in the bottom bar
itself, not per-screen. **Accounts management lives under Settings**, not as
its own tab — reached via a "Accounts" entry in Settings, same as Currencies
and Categories.

## Tech stack

- **Local DB**: `drift` (+ `drift_flutter`). Reactive `Stream` queries feed
  Riverpod directly.
- **State management**: `flutter_riverpod`, hand-written providers (no
  codegen, to avoid a second build_runner concern on top of Drift's).
- **Google Drive backup**: `google_sign_in` v7 + `googleapis` (`drive/v3`) +
  `extension_google_sign_in_as_googleapis_auth`. Scope: `drive.appdata` only
  (non-sensitive, no Google app-verification review needed).
- **Charts**: `fl_chart`.
- **Routing**: plain `Navigator`/`MaterialPageRoute` (screen set is small).

## Data model (`lib/db/`)

All amounts stored as **integers in the currency's smallest unit**
(`decimalPlaces`-driven minor units — e.g. IDR whole rupiah, USD cents, Gold
milligrams). `lib/utils/formatters.dart`'s `Money.parse`/`Money.format*` is
the one place that converts between stored ints and user-facing decimal
strings — always route amount I/O through it, don't hand-roll parsing.

- **Currencies**: code, name, symbol, `decimalPlaces`, `subunitName`
  (display label only, e.g. "cent" — doesn't affect math), `symbolBeforeAmount`,
  `isPreset`, `sortOrder`, `archivedAt`. Seed data in `lib/db/seed_data.dart`
  (14 presets incl. Gold as `XAUG`). **`sortOrder` must be set explicitly per
  seed row** (derived from list position) — leaving it at the default 0 for
  every row was a real bug found during device testing (pickers fell back to
  alphabetical, so AUD beat IDR as the default).
- **Accounts**: name, icon/color, `currencyId` (immutable at the app layer
  once the account has ≥1 transaction/transfer — enforced in
  `account_form_screen.dart`, not the DB), `initialBalance`, `archivedAt`.
- **Categories**: name, `type` ('in'|'out' — see `CategoryType` in
  `categories_table.dart`, exported from `database.dart`), icon/color,
  `archivedAt`.
- **Transactions**: in/out only. accountId, categoryId, type, amount (always
  positive; sign derived from type), note, date.
- **Transfers**: own table, not two linked Transaction rows (keeps
  `Transactions.categoryId` always meaningful; keeps cross-currency leg
  amounts first-class). `fromAccountId`/`fromAmount`,
  `toAccountId`/`toAmount`. Same-currency transfers auto-fill
  `toAmount = fromAmount` in the UI (still editable, e.g. for a fee);
  cross-currency requires both entered manually. Effective rate is computed
  on read for display, never stored.
- **Account balance**: not a stored column — computed via a raw-SQL
  correlated-subquery expression in `lib/providers/account_providers.dart`
  (`_balanceExpr`): `initialBalance + Σin - Σout + Σtransfers-in - Σtransfers-out`,
  exposed as a live `StreamProvider`. That file also shows the pattern for
  hand-rolled joined `customSelect` queries (explicit column aliases +
  manual `Account`/`Currency` reconstruction) — needed because Drift's
  `.join()` query builder can't easily be combined with a correlated
  subquery expression; use `.join()` + `.readTable()` instead
  (`transaction_providers.dart`) for joins that don't need that.

## App structure

```
lib/
  main.dart, app.dart            -- entry point, theme
  theme/colors.dart               -- brand color constants (leaf file, no deps)
  db/                              -- Drift schema, seed data
  models/                         -- join-result view types (not Drift tables)
  providers/                      -- Riverpod providers + repositories, per domain
  features/<domain>/              -- screens, one folder per feature
  widgets/                        -- shared widgets (MoneyText, IconTile, icon catalog/picker)
  utils/formatters.dart           -- Money.parse/format
```

## Conventions / feedback from the repo owner

- **Commit atomically.** One logical change per commit, ordered so each
  commit leaves the tree compiling (bottom-up: leaf files/packages first,
  screens that depend on them after). This repo's history is a good example
  to follow.
- **Never run `sudo` — hand the exact command to the user instead** and wait
  for them to run it. Comes up for apt installs (e.g. `openjdk-17-jdk-headless`,
  `ninja-build`) and udev rules.
- Match the reference app's UI closely where the repo owner has shown
  screenshots — when in doubt, ask for another screenshot rather than
  guessing at a screen that hasn't been shown.
- Verify on-device, not just `flutter analyze` — several real bugs (the
  sortOrder issue above; ADB/udev setup) only surfaced by actually running
  the app on an emulator/phone and clicking through the golden path.

## Environment setup already done on the dev machine

- Flutter SDK: `/home/prajna/codes/flutter` (on PATH via `~/.bashrc`, not
  necessarily inherited by every shell — add
  `export PATH="/home/prajna/codes/flutter/bin:$PATH"` if `flutter` isn't found).
- JDK 17 installed (`openjdk-17-jdk-headless`); `flutter config --jdk-dir`
  already points at it persistently, so `JAVA_HOME` doesn't need to be set
  per-command, though it hasn't hurt to set
  `JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64` defensively in build commands so far.
- Android SDK at `/home/prajna/Android/Sdk`. `cmdline-tools/latest` installed
  manually (the bundled legacy `tools/bin/sdkmanager` doesn't work with
  modern JDKs — `javax.xml.bind` was removed). Platform 36 + build-tools
  28.0.3/36 + platform-tools installed. Licenses accepted.
- **Ninja** (needed for native builds pulled in transitively by
  `google_sign_in`'s jni bindings) comes from the Android SDK's own `cmake`
  package, not apt: `/home/prajna/Android/Sdk/cmake/3.22.1/bin/ninja`. Add
  that dir to PATH before building
  (`export PATH="/home/prajna/Android/Sdk/cmake/3.22.1/bin:$PATH"`) — it is
  NOT on PATH by default in a fresh shell.
- An AVD `Pixel_4_API_30` exists; can also run on the repo owner's physical
  Samsung device over USB (needed a udev rule added — see git history/chat
  if it stops being detected again — vendor id `04e8`, MODE 0666, GROUP
  plugdev, `/etc/udev/rules.d/51-android.rules`).
- Full build+run recipe:
  ```bash
  export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
  export PATH="/home/prajna/codes/flutter/bin:/home/prajna/Android/Sdk/cmake/3.22.1/bin:/home/prajna/Android/Sdk/platform-tools:$PATH"
  cd /home/prajna/codes/dompetkuh
  flutter analyze && flutter test
  flutter build apk --debug   # or: flutter run -d <device-id>
  ```

## Phase status

- [x] **Phase 1 — core data + log**: schema, seed data, Riverpod providers,
      Accounts Overview/Detail/Form, Add/Edit Transaction, Manage
      Currencies, Manage Categories. Verified end-to-end on both emulator
      and the repo owner's physical device (create account → log
      transaction → balance updates live).
- [~] **Nav rework** (post-Phase-1 feedback): home tab should be a global
      Transactions log (day-grouped, per-currency income/expense/total
      summary, matching the reference screenshot exactly — plain rows, big
      day-number headers), Accounts moves under Settings, FAB becomes a
      shared center-docked "add transaction" button in the bottom bar.
      `transactionsInMonthProvider` + `GlobalTransactionEntry` +
      `TransactionsTab` added; **still need to**: wire `TransactionsTab`
      into `home_shell.dart` as the home tab with the notched center FAB,
      move `AccountsOverviewScreen` under Settings, verify on-device.
- [ ] **Phase 2 — Transfers**: Transfers table already exists in the schema
      (unused so far). Need: transfer providers/repository, Add/Edit
      Transfer screen (same-currency auto-fill amount, cross-currency dual
      amount entry), merge transfers into Account Detail's log (currently
      transactions-only).
- [ ] **Phase 3 — Reports**: currently a stub screen
      (`lib/features/reports/reports_screen.dart`). Needs per-account/
      currency totals, in-vs-out, category breakdown donut (`fl_chart`),
      period filter.
- [ ] **Phase 4 — Google Drive backup/restore**: currently a disabled stub
      row in Settings. Needs `drive_backup_service.dart` (sign-in, JSON
      export/import against Drive `appDataFolder`), Backup & Restore screen.
      **Blocked on manual setup only the repo owner can do**: Google Cloud
      project + Drive API enabled + OAuth consent screen (Testing mode is
      fine, `drive.appdata` scope doesn't need verification) + Android OAuth
      client (needs the app's `applicationId` = `com.prajnapras.dompetkuh`
      and debug/release SHA-1 fingerprints). Ask for this before starting
      Phase 4 if it hasn't been done yet.
