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

**Navigation shell** (home tab was originally Accounts, corrected per repo
owner feedback): bottom nav is **Transactions (home) / Reports / Budgets /
Settings** (2+2, split exactly at screen-center via two `Expanded` halves in
`home_shell.dart` — a fixed-width `SizedBox` spacer does NOT reliably line
up with where `centerDocked` actually cuts the FAB notch, learned the hard
way). The **center-docked FAB is a speed-dial** (matches the reference
app's Tambah Transaksi/Transfer Saldo menu): tapping it opens a small sheet
with **Add Transaction / Transfer / Add Budget** — this is the *only*
creation entry point for those three. Per-screen shortcuts (Account
Detail's FAB, Accounts Overview's transfer icon, Manage Budgets' FAB) were
deliberately removed once the speed-dial existed, per repo owner feedback
("eliminate the transfer and add transaction from the accounts menu") —
**don't re-add a per-screen Add/Transfer button**; route new creation flows
through the speed-dial instead, or ask first if a screen-specific shortcut
(e.g. one that preselects something the speed-dial can't) seems genuinely
warranted. **Accounts management lives under Settings**, not as its own
tab, and **tapping an account opens Edit directly** — there's no more
per-account transaction-log screen (Account Detail was deleted); that job
is now the home Transactions tab filtered to one account (see Budgets
section below for the filter UI, which also filters by category/budget).

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

## Budgets mechanism (easy to forget the shape of — read this before touching it)

Added after Phase 1-4, per repo owner request. **Explicitly not a spending
limit/alert system** — "no warning or anything, just budgeting" was said
verbatim. It's two things bolted together:

1. **A tag.** A `Budget` (name, icon/color) can be optionally attached to
   any in/out `Transaction` via its nullable `budgetId` — completely
   orthogonal to `categoryId`. **Transfers can never carry a budget tag**
   (no `budgetId` column on `Transfers` — tagging a transfer wouldn't mean
   anything sensible since it doesn't represent income/expense).
2. **A recurring monthly allocation.** Each `Budget` also has exactly
   **one** `currencyId` (required, like `Accounts` — otherwise summing
   "spent" across mixed currencies would be meaningless) and a single
   `monthlyAmount`. This amount **recurs identically every month** — there
   is no per-month history table. If you edit a budget's monthly amount,
   the change is retroactive: paging back to a past month in the Budgets
   tab will show *that* month's spending against the *current* amount, not
   whatever it was when that month happened. Repo owner confirmed this
   tradeoff is fine (asked directly, chose "one recurring amount" over
   building per-month amount records).

"Spent this month" and "remaining" are never stored — computed live per
viewed month by `budgetSpentInMonthProvider` (sums `out`-type transactions
tagged with that budget, within the month). `ManageBudgetsScreen` has its
own month pager for this reason, separate from the Transactions tab's.

**Where it's reachable**: its own bottom-nav tab (moved there from Settings
per repo owner feedback — "it should be in the bottom menu"), plus "Add
Budget" in the center FAB speed-dial. No FAB on the tab itself (redundant
with the speed-dial). Archive/unarchive is the same active/inactive
mechanism as Currencies/Categories (see Conventions below) — hides a
budget from the transaction-tagging dropdown without losing its history.

**Tagging UX gotcha**: the Budget dropdown in Add/Edit Transaction is
filtered to only the selected account's currency, and is keyed on
`ValueKey(_accountId)` in `add_transaction_screen.dart` — `DropdownButtonFormField`
does not re-read `initialValue` on rebuild (a general Flutter gotcha, not
specific to this field), so without that key, switching to an account in a
different currency could leave the dropdown holding a `_budgetId` that's
no longer in its (re-filtered) item list and crash. `_budgetId` is also
explicitly reset to `null` in the Account dropdown's `onChanged` for the
same reason.

## Reports period selector

`utils/report_period.dart`'s `ReportPeriod` (Daily/Monthly/Yearly/All/
Custom) replaced the old fixed month pager, matching the reference app's
Laporan calendar-icon menu (Harian/Bulanan/Tahunan/Semua/Sesuaikan).
`report_providers.dart` takes an optional `(start, end)` range (both null
= all-time) rather than a hardcoded month. Tapping a category in the
breakdown drills down into the Transactions tab, pre-filtered to that
category, opened on the month containing the period's `reference` date
(closest equivalent for nonmonthly periods, since the Transactions tab
itself still only pages by month — it wasn't asked to grow the same
Daily/Yearly/All/Custom selector).

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
- [x] **Nav rework** (post-Phase-1 feedback): home tab is now the global
      Transactions log (`features/transactions/transactions_tab.dart`) —
      month pager, per-currency income/expense/total summary (plain rows,
      never blended), day-grouped entries with big day-number headers.
      `HomeShell` bottom nav is Transactions/Reports/Settings with a
      `BottomAppBar` + `CircularNotchedRectangle` + centerDocked pencil FAB.
      `AccountsOverviewScreen` moved under Settings. Also fixed Material 3's
      default pastel tinting (`app.dart`) since it didn't match the
      reference app's flat saturated colors — verified visually on-device
      before the physical device was disconnected.
- [x] **Phase 2 — Transfers**: `Transfers` table wired up. Transfer entry
      point is the FAB speed-dial now (see Navigation shell above), not a
      per-screen icon. Transfers are excluded from the Transactions tab's
      income/expense summary (they move money between your own accounts)
      but do show as line items everywhere, including the Reports drill-
      down's account/category filters where applicable.
- [x] **Phase 3 — Reports**: currency selector + `ReportPeriod` selector
      (see dedicated section above) + Income/Expense toggle + `fl_chart`
      donut/breakdown, with drill-down into a filtered Transactions tab.
- [x] **Phase 4 — Google Drive backup/restore. Code complete, credentials
      configured, but the actual sign-in/backup/restore flow has still
      never been exercised end-to-end on-device** (blocked each time so
      far on the repo owner's phone being connected). `services/
      export_import.dart` (DB <-> versioned JSON, transactional restore),
      `services/drive_backup_service.dart` (backup/list/restore/prune
      against Drive `appDataFolder`, only the non-sensitive `drive.appdata`
      scope), `providers/backup_providers.dart` (sign-in state via
      `GoogleSignIn.instance.authenticationEvents` — see the "stream must
      never error" note below —, `shared_preferences`-backed last-backup
      timestamp), `features/backup/backup_settings_screen.dart`.

      **Google Cloud setup is done**: Drive API enabled, OAuth consent
      screen **published to Production** (repo owner's choice, so any
      Google account can sign in — not just pre-listed test users; each
      account sees a one-time "unverified app" warning to click through,
      accepted as fine for a personal app), Android OAuth client
      (`com.prajnapras.dompetkuh`, debug SHA-1
      `25:26:26:AF:61:82:6A:D9:31:A4:95:94:17:D7:7F:F1:8F:8C:07:91` — a
      **second** Android client with the release SHA-1 will be needed once
      a release keystore exists), Web OAuth client created and its ID
      hardcoded as the default in `services/google_config.dart`'s
      `GOOGLE_SERVER_CLIENT_ID` (client IDs are public identifiers, not
      secrets, so this is fine to commit — still overridable via
      `--dart-define` if it ever needs to change).

      **Real bug already found and fixed here, worth knowing about**: a
      failed/cancelled sign-in attempt surfaces as an error event on
      `GoogleSignIn.instance.authenticationEvents`. The naive
      implementation let that propagate into `currentGoogleAccountProvider`'s
      `StreamProvider`, which has no automatic recovery from an `AsyncError`
      state — the Backup screen got stuck showing raw error text with no
      way back to the Sign In button. Fixed by swallowing errors on that
      stream (`.handleError((_, __) {})`) and treating any lightweight-auth
      failure as plain "not signed in" (`null`) instead — this stream's
      only job is tracking current sign-in state, never surfacing
      transient auth errors; actual failures are reported by
      `BackupActions.signIn()`'s own caller via try/catch + a snackbar.
      **If touching this stream again, preserve that property.**

      Next step: verify the actual golden path once a device is connected:
      sign in -> back up -> change some data locally -> restore -> confirm
      the change reverted -> sign out.
- [x] **Post-Phase-4 polish round**: Budgets feature (see dedicated section
      above), Transactions tab filters + Reports period selector + drill-
      down (see dedicated sections above), removed all per-screen Add/
      Transfer shortcuts in favor of the FAB speed-dial (see Navigation
      shell above), account tap now opens Edit directly (Account Detail
      screen deleted), live thousands-grouping on amount fields
      (`utils/thousands_input_formatter.dart`) plus a plain-language
      cents/subunit hint (`amountDecimalHint` in `formatters.dart`) since
      "where do I put the cents" wasn't obvious, currency archive re-
      surfaced as a Switch (clearer than a buried "Archive" menu item),
      custom app icon (was still the default Flutter logo — generated via
      PIL + `flutter_launcher_icons`, source at `assets/icon/`), and
      bottom safe-area padding added to every form's `ListView` (the last
      button, e.g. DELETE, was getting covered by the gesture-nav bar on
      the repo owner's device — `MediaQuery.of(context).padding.bottom`
      added to each form's bottom padding; apply the same pattern to any
      new form screen with a button as its last child).
