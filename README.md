# QuitSmart: Freedom from Smoking

A single-page web app that helps people stop smoking without relying on willpower. It combines three ideas:

- **Easyway-style reframing**: a 6-day plan that takes apart the beliefs behind smoking (stress relief, pleasure, routine, sacrifice).
- **Mindful smoking**: during prep, users keep smoking but log each cigarette and rate how much they actually enjoyed it.
- **Hooked model**: one-tap SOS for cravings (trigger → action), varied rewards, and a journal that turns logs into personal trigger insights (investment).

## Features
- Onboarding (no passwords), prep → free stages, freedom clock, money and life-reclaimed stats
- 6-day plan with before/after belief ratings, reflections and a final-cigarette ritual
- Craving SOS: wave timer, trigger + strength, 4-7-8 / box breathing, body scan, 5-4-3-2-1 grounding, generated soundscapes
- Slip flow (no shame), daily check-in streak, reward goal
- Journal with 7-day chart, top triggers, time of day, best tools
- Body recovery timeline (CDC / Surgeon General milestones)
- 25 pop-art medals, 64 daily truths, light and dark mode
- Backup / restore (copy-paste), import from the previous version

## Files
| File | Purpose |
|---|---|
| `index.html` | The whole app (HTML + CSS + JS in one file) |
| `netlify.toml` | Netlify settings: no build step, publish the repo root |

## Deploy on Netlify
1. Netlify → **Add new site → Import an existing project → GitHub** → pick this repo.
2. Build command: *(leave empty)*. Publish directory: `.`
3. Deploy. Every push to `main` redeploys automatically.

## Data
Everything is stored in the browser (`localStorage`) through one `Store` object at the top of the script.
That object is the only place to change when moving to Supabase (accounts + sync across devices).

## Roadmap
- [ ] Supabase auth + sync (swap the `Store` layer, add row-level security)
- [ ] Installable app (PWA) with daily check-in reminders
- [ ] Custom domain

*General information, not medical advice. India National Tobacco Quitline: 1800-11-2356.*
