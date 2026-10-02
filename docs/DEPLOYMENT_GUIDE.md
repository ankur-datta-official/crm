# Deployment Guide

This guide prepares the CRM for a Vercel + Supabase staging or production deployment.

## 1. Supabase project setup

1. Create a Supabase project.
2. Copy:
   - project URL
   - publishable key
   - service role key for future server-only admin jobs if ever needed
3. Keep the service role key private.

## 2. Migration run order

Run the default fresh-install migration chain in this order:

1. `001_core_saas_schema.sql`
2. `002_seed_platform_data.sql`
3. `003_crm_base_company_management.sql`
4. `004_contact_person_management.sql`
5. `005_interaction_meeting_log.sql`
6. `006_followup_reminder_management.sql`
7. `007_document_management.sql`
8. `008_need_help_escalation.sql`
9. `009_team_role_permission_management.sql`
10. `010_subscription_plan_limits.sql`
11. `012_notifications_search_polish.sql`

Important:

- `012_notifications_search_polish.sql` replaces the old duplicate `011` notifications reference.
- `011_fix_admin_permissions.sql` is a legacy repair migration for older upgraded environments only, not part of the standard fresh staging setup.

## 3. Storage bucket setup

Create a private Supabase Storage bucket:

```bash
crm-documents
```

Recommended object path:

```bash
organization_id/company_id/document_id/original-file-name
```

## 4. Required environment variables

Configure these in Vercel and local `.env.local`:

```bash
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=
# NEXT_PUBLIC_SUPABASE_ANON_KEY=
NEXT_PUBLIC_APP_URL=

SUPABASE_SERVICE_ROLE_KEY=

REMINDER_EMAIL_ENABLED=
SMTP_HOST=
SMTP_PORT=
SMTP_USER=
SMTP_PASSWORD=
SMTP_FROM=
CRON_SECRET=
```

Notes:

- `SUPABASE_SERVICE_ROLE_KEY` must stay server-only.
- `NEXT_PUBLIC_APP_URL` should point to the deployed frontend origin.
- If email reminders are not used yet, keep `REMINDER_EMAIL_ENABLED=false`.

## 5. Vercel deployment steps

1. Push the repo to GitHub.
2. Import the project into Vercel.
3. Add the environment variables above.
4. Set the production branch.
5. Trigger a deployment.
6. Confirm `npm run build` succeeds in Vercel build logs.

## 6. Supabase Auth redirect setup

Set Supabase site URL to your deployed frontend URL.

Add redirect URLs for:

- `/auth/login`
- `/auth/register`
- `/onboarding/workspace`
- `/auth/accept-invite`

Example:

```bash
https://your-app.vercel.app/onboarding/workspace
https://your-app.vercel.app/auth/accept-invite
```

## 7. Cron reminder endpoint setup

The reminder endpoint is:

```bash
/api/cron/followup-reminders
```

Use one of these auth methods:

- `Authorization: Bearer <CRON_SECRET>`
- `?secret=<CRON_SECRET>`

Recommended:

- Use a server-side scheduler such as Vercel Cron with the bearer token.

## 8. Optional demo seed

An optional seed file is available at:

```bash
supabase/seeds/demo_data.sql
```

Use it only in local or staging environments. Do not auto-run it in production.

## 9. Post-deployment smoke test

1. Register a new test user.
2. Create a workspace.
3. Open `/dashboard`.
4. Create a company.
5. Create a contact.
6. Create a meeting.
7. Create a follow-up.
8. Upload a small document.
9. Create a help request.
10. Open `/reports`.
11. Open `/team`.
12. Open `/subscription`.
13. Test topbar search.
14. Test the notification center.
15. Log out and confirm protected route redirects still work.
