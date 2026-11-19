# QuitSmart: Freedom from Smoking

A single-page web app that helps people stop smoking without relying on willpower. It combines three ideas:

- **Easyway-style reframing**: a 6-day plan that takes apart the beliefs behind smoking (stress relief, pleasure, routine, sacrifice).
- **Mindful smoking**: during prep, users keep smoking but log each cigarette and rate how much they actually enjoyed it.
- **Hooked model**: one-tap SOS for cravings (trigger → action), varied rewards, and a journal that turns logs into personal trigger insights (investment).

## Features
- Onboarding (no passwords), prep → free stages, freedom clock, money and life-reclaimed stats
- 6-day plan with before/after belief ratings, reflections and a final-cigarette ritual
- Craving SOS: wave timer, trigger + strength, 4-7-8 / box breathing, body scan, 5-4-3-2-1 grounding, generated soundscapes
- Guided daily sessions: Learn → Rethink → Practice → Journal → Mission (prep track + "Stay Free" track for people who've already quit)
- Learn Library (14 science cards) + Science & Further Reading page (verified journal references, vetted talks/podcasts, Indian helplines)
- Craving Chess: built-in chess engine with 4 bots (≈800 / 1200 / 1500 / 1800)
- Freedom Quest: 4 regions / 12 card battles; Breath, Time, Gold and Resolve come from real progress; 16 power cards unlocked by real actions
- Avatar builder (or photo) with a ring that levels up Bronze → Diamond; shown in header, Settings and Freedom Quest
- Support page (India, UPI QR + app link), shown rarely and never during cravings, prep or after a slip
- Guided "Write It Down" journal with prompts; 3 text sizes
- Slip flow (no shame), daily check-in streak, reward goal, days reset at local midnight
- Journal with 7-day chart, top triggers, time of day, best tools
- Body recovery timeline (CDC / Surgeon General milestones)
- 32 animated achievements (Bronze → Silver → Gold → Platinum → Diamond) with unlock celebrations, 64 daily truths, light and dark mode
- Backup / restore (copy-paste), import from the previous version

## Files
| File | Purpose |
|---|---|
| `index.html` | The whole app (HTML + CSS + JS in one file) |
| `netlify.toml` | Netlify settings: no build step, publish the repo root |
| `supabase/setup.sql` | One-time database setup for optional accounts, sync and invites |
| `supabase/research.sql` | One-time setup for the optional anonymous research table |
| `manifest.webmanifest`, `sw.js`, `icons/` | Installable app (home-screen icon, works offline) |

## Deploy on Netlify
1. Netlify → **Add new site → Import an existing project → GitHub** → pick this repo.
2. Build command: *(leave empty)*. Publish directory: `.`
3. Deploy. Every push to `main` redeploys automatically.

## Support payments
UPI ID and payee name live in `SUPPORT_CONFIG` near the bottom of `index.html` (search for `SUPPORT_CONFIG`).

## Data & optional accounts
Everything works offline in the browser (`localStorage`). Signing in is optional.

- Supabase project URL and publishable key live in `CLOUD` (search `const CLOUD`). The publishable key is meant for client code; security comes from Row Level Security.
- **One-time setup:** Supabase → SQL Editor → New query → paste `supabase/setup.sql` → Run.
- Auth: email one-time code. The Magic Link (and Confirm sign up) email template must include `{{ .Token }}`. Configure custom SMTP before launch; the built-in sender only allows a few emails an hour.
- Synced: the app state (minus the avatar photo). Invite links use `?ref=CODE`; a friend counts once they sign in and have saved progress.
- Legal texts and the grievance contact live in `LEGAL_CONFIG` (search `const LEGAL_CONFIG`).
- Optional research: run `supabase/research.sql`. Results: SQL Editor → `select * from research_summary;` (groups under 5 people are hidden). Rows are never linked to accounts.

## Roadmap
- [x] Supabase auth + sync + invites (row-level security)
- [x] Installable app (PWA, offline)
- [x] Shareable milestone images
- [x] Opt-in anonymous research
- [ ] Push reminders (needs a scheduled Supabase Edge Function + web push keys)
- [ ] Custom domain

*General information, not medical advice. India National Tobacco Quitline: 1800-112-356.*
