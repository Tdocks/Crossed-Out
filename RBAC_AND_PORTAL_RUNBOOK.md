# Roles, Verification & Church Portal — Runbook

This ships three-tier roles, church-account verification, and the church
portal. Everything below is the setup order. Nothing here is destructive;
migration 0021 is idempotent.

## What was built

**Roles (migration 0021)** — every account now has a `role`
(`user` / `church_admin` / `system_admin`) and an `account_status`
(`active` / `pending_verification` / `suspended`).

- **Regular users** self-sign-up and are `active` immediately (unchanged).
- **Churches that self-sign-up in the app** become `church_admin` /
  `pending_verification` and get **no app access** until you verify them.
- **Churches that sign up via an invite link** are auto-approved `active`.
- **You (tdoxwell@icloud.com)** are auto-promoted to `system_admin`.

Role, status and church linkage are **not** client-writable — a user cannot
make themselves an admin. All privileged changes go through `SECURITY DEFINER`
RPCs, and direct writes to those columns (and to the `churches` table) are
revoked at the grant layer.

**In the app**
- `More → Manage My Church` (church admins) — edit church name, city,
  denomination, style, YouTube channel, website, contact email.
- `More → Admin` (you) — mint invite links + verify/reject pending churches.
- Welcome screen → "Represent a church? Register here" → in-app church signup
  (lands on a pending-verification screen).

**Church portal** (`portal/church-portal.html`) — a single static page:
- `…/church-portal.html?invite=<token>` → a church rep's auto-approved signup.
- `…/church-portal.html` (no token) → your web admin console (mint invites,
  verify pending churches), in case you'd rather do it from a browser.

---

## Setup steps

### 1. Apply migration 0021
Apply `supabase/migrations/0021_rbac_and_church_portal.sql` the same way you
applied 0016–0020 (your DB password was rotated, so use your current method —
`supabase db push`, the dashboard SQL editor, or psql with the current
password). It only adds columns/policies/functions and backfills your admin
role; it does not touch existing data.

### 2. Confirm you're a system admin
The migration's backfill promotes any existing account whose email is in
`system_admin_emails` (seeded with yours). After applying, verify:

```sql
select id, role, account_status from public.profiles
where id = (select id from auth.users where email = 'tdoxwell@icloud.com');
-- expect: role = system_admin, account_status = active
```

If that returns no row (profile not created yet), just open the app once while
signed in as yourself — the insert trigger promotes you automatically — or
re-run the backfill block at the bottom of 0021.

To grant another system admin later:
`insert into public.system_admin_emails(email) values ('name@example.com');`
then that account is promoted on its next profile insert (or re-run the
backfill).

### 3. Host the portal + point the app at it
1. Host `portal/church-portal.html` on any static host (Cloudflare Pages,
   Netlify, Vercel, or Supabase Storage). Note the final URL.
2. Set that URL in **`CrossedOut/Features/Admin/AdminHubView.swift`** →
   `PortalConfig.baseURL` (currently a placeholder), so the in-app
   "Generate invite link" builds correct links. The portal's own admin
   console builds links from its own address, so it works regardless.
3. Rebuild the app after changing that constant.

> **Email confirmation:** if your Supabase project requires email confirmation,
> a church rep signing up via the portal will be told to confirm their email,
> then return to the same link and tap "Sign in to finish" — the portal then
> redeems the invite. If confirmation is off, it completes in one step. Both
> paths are handled.

### 4. Xcode project + build
New Swift files were added, so the project was regenerated with
`xcodegen generate` and **builds clean** (verified). If you pull this on
another machine: `xcodegen generate` then build in Xcode.

### 5. (Per church) turn on their live stream
Portal/app church signups store the church's YouTube handle but don't resolve
the channel automatically. To enable live streaming for a new church, run the
existing one-command pipeline with their handle:

```bash
./scripts/add_church.sh "@theirhandle" "City" "Denomination" "Style"
```

This resolves the channel, wires up `live_services`, and the scheduled refresh
worker takes over. (A future portal enhancement can trigger this automatically.)

---

## The three signup flows

1. **Regular user** — Get Started → onboarding → account. `user` / `active`.
   No change from before.
2. **Church, in the app** — Welcome → "Represent a church? Register here" →
   create account → church application form → **pending screen**. You approve
   it in `More → Admin` (or the web console). On approval their church
   publishes and their account goes `active`.
3. **Church, by invite** — You mint a link (`More → Admin` or the portal
   console) and send it. They open it, sign up, and are **auto-approved** —
   church published, account `active` — and can immediately sign into the app.

Both church flows write the church's details into its `churches` row (the
"profile segment" that powers the Attend tab); the rep's personal account is
the linked `church_admin` profile.

---

## Verification checklist
- [ ] `0021` applied without error.
- [ ] Your profile shows `role = system_admin`.
- [ ] App builds; `More → Admin` appears for you, not for a normal test user.
- [ ] Mint an invite in `More → Admin`; open the link in a browser → church
      signup form appears prefilled.
- [ ] Complete an invite signup → that account can sign into the app with no
      pending gate, and `More → Manage My Church` shows their church.
- [ ] In-app church signup → lands on the pending screen; after you tap Verify
      in Admin, "Check status" lets them into the app.
- [ ] A normal user still signs up and uses the app exactly as before.

## Security notes
- A user **cannot** self-escalate: table-level `INSERT`/`UPDATE` on
  `profiles` is revoked and re-granted only for the safe columns, so
  `role`/`account_status`/`church_id` fall to defaults and are writable only
  by the definer RPCs. All `churches` writes are RPC/service-role only.
- Pending/suspended accounts can't post to community (enforced in RLS, not
  just the client).
- Unpublished churches (and their live services) are hidden from everyone
  except their own admin and system admins.
