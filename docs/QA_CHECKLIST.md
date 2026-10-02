# QA Checklist

Use this checklist for final manual QA before a demo, staging release, or production deployment.

## Auth and onboarding

- Register a new user from `/auth/register`.
- Log in from `/auth/login`.
- Confirm invalid credentials show a user-friendly error.
- Confirm new users are redirected to `/onboarding/workspace`.
- Create a workspace successfully.
- Confirm logged-in users with a workspace land on `/dashboard`.
- Confirm logout returns the user to a public/auth screen.

## Dashboard

- Confirm dashboard stats load without layout breaks.
- Confirm active users and pending invitations widgets load if enabled.
- Confirm dashboard data is scoped to the current organization only.
- Confirm redesigned KPI cards show real CRM data only.
- Confirm Today's Tasks merges real follow-ups, help requests, and meetings correctly.
- Confirm the pipeline funnel uses real pipeline stages.
- Confirm the lead trend chart handles empty data cleanly.
- Confirm the deals-by-stage donut chart handles empty data cleanly.
- Confirm alert cards link to the correct modules.
- Confirm the mobile dashboard layout stacks cleanly without horizontal overflow.
- Confirm no fake dashboard data appears anywhere.
- Confirm the header matches the reference-style airy layout.
- Confirm the KPI row feels compact and balanced.
- Confirm Today's Tasks does not render as an oversized/tall card.
- Confirm the Monthly Activity Target visual progress is readable and accurate.
- Confirm the pipeline funnel reads visually as a funnel, not simple bars.
- Confirm the lower chart row stays balanced without oversized whitespace.
- Confirm the alerts row renders as 3 cards or one no-critical-alert state.
- **Currency Formatting:** Confirm all monetary values display with ৳ (Bangladeshi Taka) instead of $.
- **Currency Formatting:** Confirm dashboard Pipeline Value KPI uses ৳ formatting.
- **Currency Formatting:** Confirm pipeline funnel summary shows ৳ formatted values.
- **Pipeline Overview:** Confirm funnel uses multicolor trapezoid layout with proper tapering widths.
- **Pipeline Overview:** Confirm each stage displays name and count badge within colored segments.
- **Pipeline Overview:** Confirm funnel displays pipeline total value summary below.
- **Deals by Stage:** Confirm donut chart shows center label with total deals count.
- **Deals by Stage:** Confirm legend displays stage name, deal count, and percentage.
- **Deals by Stage:** Confirm tooltip shows stage name, deal count, and percentage on hover.
- **Visual Polish:** Confirm KPI cards have refined shadows, ring accents, and clean typography.

## Companies

- Create a company from `/companies/new`.
- Search and filter companies.
- Open company detail.
- Edit company.
- Archive company.
- Confirm company list does not create full-page horizontal scroll.

## Pipeline

- Open `/pipeline`.
- Confirm active stages render as Kanban columns.
- Confirm empty stages explain how to move a deal there or add a new lead.
- Drag a company from one stage to another.
- Move a company to Won from a deal card.
- Move a company to Lost from a deal card.
- Confirm the stage change appears on the company profile.
- Test search and board filters.
- Confirm the board scrolls horizontally inside the board container only.
- Confirm activity logs capture `company.pipeline_stage_changed`.
- Confirm the board remains readable on mobile or narrow viewport sizes.

## Contacts

- Create a contact from `/contacts/new`.
- Set a primary contact.
- Search and filter contacts.
- Open contact detail.
- Edit contact.
- Archive contact.

## Meetings

- Create a meeting from `/meetings/new`.
- Search and filter meetings.
- Open meeting detail.
- Edit meeting.
- Archive meeting.

## Follow-ups

- Create a follow-up from `/followups/new`.
- Search and filter follow-ups.
- Complete a follow-up.
- Reschedule a follow-up.
- Cancel a follow-up.
- Archive a follow-up.

## Documents

- Upload a document from `/documents/new`.
- Confirm file size validation is user-friendly.
- Confirm storage limit validation is user-friendly.
- Open document detail.
- Download a document.
- Upload an image file and confirm the detail page shows a preview.
- Upload a PDF and confirm the detail page shows an embedded preview or fallback download path.
- Upload an Office file and confirm a clean preview placeholder appears.
- Confirm clicking Download automatically saves the file to the device.
- Confirm document previews and downloads still work with a private `crm-documents` bucket.
- Edit document metadata.
- Archive a document.

## Need Help

- Create a help request from `/need-help/new`.
- Search and filter help requests.
- Assign a help request.
- Resolve a help request.
- Reopen a help request.
- Archive a help request.

## Reports

- Open `/reports`.
- Confirm protected access requires the correct permission.
- Confirm the reports page feels clear on first impression and does not look overly crowded.
- Test filters.
- Test export actions available for the current plan and permissions.
- Confirm charts show a clean empty state when there is no report data.
- Confirm charts remain readable and responsive on smaller screens.

## Team and permissions

- Open `/team`.
- Confirm current user appears in Team Members.
- Confirm users without `full_name` show an email-prefix fallback.
- Create an invite.
- Copy the invite link.
- Cancel and resend invites.
- Change a user role.
- Deactivate and reactivate a user.
- Edit role permissions.

## Profile settings

- Open `/settings/profile`.
- Update full name.
- Update phone, designation, and department.
- Upload an avatar image.
- Confirm the avatar appears in the topbar.
- Try an invalid file type and confirm it is blocked.
- Try a large image over 2MB and confirm it is blocked.
- Confirm email remains read-only.

## Subscription

- Open `/subscription`.
- Confirm plan cards remain ordered:
  - Starter
  - Professional
  - Business
  - Enterprise
- Confirm usage cards load.
- Test manual plan switching if `subscription.manage` is allowed.
- Test team invite seat limit.
- Test company creation limit.
- Test document upload limits.

## Global search

- Search company name.
- Search contact email or mobile.
- Search meeting discussion text.
- Search follow-up title.
- Search document title or file name.
- Search help request title or description.
- Confirm search dropdown closes on Escape.
- Confirm search dropdown closes on outside click.
- Confirm clicking a result opens the correct detail page.
- Confirm Enter opens `/search?q=...`.

## Notifications

- Create an action that should generate a notification.
- Confirm unread badge count updates.
- Confirm recent notifications appear in the dropdown.
- Confirm clicking a notification marks it as read.
- Confirm "Mark all as read" works.
- Confirm the dropdown stays inside the viewport on smaller screens.

## Security and tenant isolation

- Confirm protected pages redirect unauthenticated users to `/auth/login`.
- Confirm inactive users are redirected to `/unauthorized`.
- Confirm `/team` requires `team.view`.
- Confirm `/reports` requires `reports.view`.
- Confirm `/settings` requires `settings.view` or `settings.manage`.
- Confirm `/subscription` requires `subscription.view`.
- Confirm one organization cannot view another organization's data through search, lists, reports, invites, or notifications.

## Guidance strips

- Confirm dismissible guidance strips can be closed on major CRM pages.
- Confirm dismissed guidance stays hidden after refresh via localStorage.

## Final checks

- Review the main CRM pages for visual consistency in headers, cards, buttons, inputs, tables, and badges.
- Review module-wise UX clarity on the main CRM pages:
  - Page title is clear.
  - Primary CTA is clear.
  - Empty state is helpful.
  - Filters are usable without feeling overwhelming.
  - Mobile view remains readable.
- Review major create and edit forms for UX quality:
  - Required fields are clear.
  - Optional sections are visible by default.
  - Cancel returns to the correct place.
  - Save works.
  - Save & Add Another works where available.
  - Validation and upload errors are user-friendly.
  - Mobile layout remains readable.
- Run a dedicated form QA pass:
  - Required fields match validation.
  - Optional sections are visible by default.
  - Save bar does not overlap content.
  - Required asterisks are correct.
  - Optional email and URL validation works only when values are provided.
  - Save and edit flows work.
  - Mobile form layout works.
- Review list and table UX quality:
  - No full-page horizontal scroll appears.
  - Filters are understandable and "More filters" reads like an action trigger.
  - Primary row or card action is clear.
  - Mobile cards remain readable.
  - Empty states are helpful.
- Review final visual polish and micro-interactions:
  - Hover states feel consistent and subtle.
  - Loading states look clean.
  - Success and error feedback is understandable.
  - Modals are clear and button intent is obvious.
  - Dropdowns do not overflow the screen.
  - Focus rings remain visible.
  - Mobile layouts still feel comfortable.
- Run `npm run build`.
- Run `npm run typecheck`.
- Run `npm run lint`.
- Note current acceptable lint warnings if unchanged:
  - React Hook Form `watch()` compatibility warnings in the CRM form components.
