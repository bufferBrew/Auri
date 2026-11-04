<!-- BEGIN brew-shared (synced from ~/Desktop/code/brew/AGENTS.md by sync-agent-rules.sh; do not edit here) -->

# Brew ecosystem — shared agent rules

Rules for every app in the Brew family (bufferBrew GitHub org). They apply to
any coding agent — Claude Code, Codex, Cursor, Gemini, Copilot — working in
any Brew repo. App-specific rules live in that repo's own `CLAUDE.md` /
`AGENTS.md` below the shared block; where the two conflict, the app's own
rules win for that app.

Canonical source: `~/Desktop/code/brew/AGENTS.md`. Each repo carries a synced
copy between `brew-shared` markers — edit the canonical file, then run
`~/Desktop/code/brew/sync-agent-rules.sh`. Never edit the synced block in place.

## Members

Brew apps live under `~/Desktop/code/brew/`, one git repo per folder:
BREW, BrewHire, BrewTales, BrewWire, NeuroBrew, WealthBrew, brewfeed.
BrewSkolar was merged into NeuroBrew and retired (2026-10-05).

Not Brew, whatever older docs say: `craftsman`, `castack`, `WinCtrl`,
`LitmusLLM`. Don't rename those or fold them into Brew docs.

## App boundaries

Before adding a feature, check it belongs to the app you're in:

| App | Owns | Rule |
|---|---|---|
| BrewWire | News APIs, RSS, sports, and the daily AI brief with its collector | Pulls from external sources? It goes here |
| brewfeed | Notes, linked Notion pages, Blogging drafts | Fetches nothing; shows what you put in |
| NeuroBrew | Courses, deep dives, voiceover, learning progress from a topic or source | The goal is to understand something? It goes here |

Apps hand off to each other by link only (e.g. a BrewWire story opens
NeuroBrew's new-course screen with `?topic=`). They never read each other's
schema.

## Naming

- New products/modules get a `<Thing>Brew` (or `Brew<Thing>`) name and target
  the `bufferBrew` org. No ad-hoc names.
- Supabase Edge Function slugs are flat across the shared project, so prefix
  them with the app: `brewwire-*`, `brewfeed-*`, `neuro-*`, `core-*`.

## Repo hygiene

- Each folder is its own repo with its own remote and dependencies. `cd` into
  it and treat it as the root; never edit or commit in a sibling app as a
  side effect.
- Stage files by name. No `git add -A` / `git add .`.
- **Never commit `graphify-out/`** — not even as a separate graph commit. If an
  app's own docs say to commit the graph, flag the conflict instead.
- Shared Flutter code lives in `bufferBrew/brew-packages`
  (`~/Desktop/code/apps/packages`, a pub workspace). Only schema-agnostic
  client code belongs there — HTTP/LLM provider dispatch, Supabase bootstrap,
  auth helpers — never a repository class tied to one app's tables.
- Apps depend on it by **git dep pinned to the commit SHA of a release tag**,
  with the tag in a comment (`ref: 9102a5b… # v0.2.2`), never a committed
  `path:` dep — a fresh clone of one app must build on its own. Not the tag
  name: brew_auth/brew_ui reach brew_core by an in-repo path, which pub records
  as the SHA, and a tag-name ref then counts as a different source and fails
  to resolve. Get the SHA with
  `git ls-remote https://github.com/bufferBrew/brew-packages.git 'refs/tags/vX.Y.Z^{}'`.
  To develop against a local checkout, add a git-ignored
  `pubspec_overrides.yaml` pointing at `../../apps/packages/<pkg>` — only
  while you're editing the package. It rewrites `pubspec.lock` to a `path:`
  source; never commit the lock in that state. Delete the override, tag a
  brew-packages release, bump `ref`, `pub get`, then commit.

## Shared Supabase project

Every Supabase-backed Brew app runs on **one** project: `torjnuovzvjgmkzokvfw`
("AI Dashboard", eu-west-1). The old `lijzebwgdvlywsspxjvv` ("NewsBrew")
project is unused.

Apps are isolated by **Postgres schema**, not by project:

| Schema | Owner |
|---|---|
| `public` | BREW (+ NeuroBrew's `nb_*` and the `content_*` pipeline) |
| `core` | cross-app contract layer — app registry, outbox, shared LLM keys/connections. BREW owns it; every app may write its own rows |
| `voyage` | BrewVoyage (inside BREW) |
| `brewwire` | BrewWire |
| `brewfeed` | BrewFeed |
| `hire` | BrewHire |
| `wealth` | WealthBrew |

All of these fail silently if ignored:

- **No app reads another app's schema.** The only crossing point is `core.*`;
  cross-app data travels as a denormalized push into the `core.app_events`
  outbox. Why: `BREW/supabase/migrations/0040_core_schema.sql`.
- **A new schema must be exposed** under dashboard → Project Settings → Data API
  → Exposed schemas (`PGRST106` otherwise). No SQL/CLI equivalent. Procedure:
  `BREW/docs/22-Core-Cutover-Runbook.md`.
- **Every client names its schema**, service-role clients included —
  service_role bypasses RLS, not PostgREST schema routing.
- **`supabase db push` only works from `BREW`.** The migration ledger is
  shared, so a push from any other app fails with
  `LegacyDbPushMissingLocalError`. Never run the
  `migration repair --status reverted` it suggests — that rewrites another
  app's history. Satellites apply migrations via the Supabase MCP or SQL
  editor, then `supabase migration fetch` into a scratch dir and copy their
  own file back into the repo.
- **Fresh installs use bundles, not migrations.** An install onto a new
  Supabase (self-hosting, a standalone app) runs brew-packages'
  `supabase/core/` bundle and then the app's own `supabase/bundle/`, via
  `brew-migrate` (brew-packages `supabase/README.md`). So a schema change goes
  in **two** places: a migration for the shared project, and a new
  `supabase/bundle/000N_….sql` (or `supabase/core/000N_….sql` for `core`) for
  fresh installs. Never edit an applied bundle file; brew-migrate refuses it.
- **Test users:** one `auth.users` row serves every app — triggers fan signups
  out to `public.users`, `brewwire.users`, `brewfeed.users`. Use the shared
  test account `brew.test01@example.com`; don't create per-app test users.

## Pending user actions (Notion)

Every job in a Brew app ends by updating that app's pending user actions in
Notion, under **Brew Labs › Brew Apps Index**, one child page per app (e.g.
"WealthBrew — what's done and what's left"). Applies at all times, to every
job, whatever its size.

- Add anything only the user can do: secrets and API keys, dashboard toggles
  (exposed schemas, OAuth), store/signing steps, device checks, decisions.
- Tick or remove items that are done, after checking the live state (e.g. a
  SQL query for Vault secrets), not from memory.
- No page for the app yet: create one under Brew Apps Index.
- The older "Steps for Live" database under bufferBrew Repos is not the target.

## Latest APKs in Google Drive

Every app with an Android build keeps its latest APK in Google Drive › apk
(the synced folder `~/Library/CloudStorage/GoogleDrive-…/My Drive/apk`). Whenever
a job lands changes on an app's default branch:

- Build the APK from the default branch (release where it builds, else debug),
  using the file name already in the folder (`<App>-release.apk` /
  `<App>-debug.apk`).
- Check it with `apksigner verify`, then overwrite the old file.
- Note it on the app's Notion page. Overwriting can change the Drive file id,
  so re-check any Notion link to the file.

<!-- END brew-shared -->
