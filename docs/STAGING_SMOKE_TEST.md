# Staging Smoke Test

Run this checklist after every staging deployment.

## Auth test

- Open `/auth/login`.
- Sign in successfully.
- Confirm invalid credentials show a friendly error.
- Log out and confirm protected routes redirect correctly.

## Workspace test

- Register a new user if needed.
- Complete workspace onboarding.
- Confirm the user lands on `/dashboard`.

## CRM CRUD test

- Create, view, edit, and archive a company.
- Open `/pipeline` and confirm the new company appears in the expected stage.
- Drag the company to another stage and confirm the move succeeds.
- Move a company to Won and then to Lost if staging data allows.
- Create, view, edit, and archive a contact.
- Create, view, edit, and archive a meeting.
- Create, complete, and archive a follow-up.
- Create, assign, resolve, and reopen a help request.

## File upload test

- Upload a small file to `/documents/new`.
- Open the document detail page.
- Download the file.
- Confirm validation errors are friendly if a file is too large.

## Search test

- Search for a company.
- Search for a contact email.
- Search for meeting discussion text.
- Confirm `/search?q=...` works.
- Confirm a pipeline-moved company is still discoverable through search and profile links.

## Notification test

- Trigger a follow-up assignment or help-request assignment.
- Confirm the bell unread count updates.
- Open the dropdown.
- Mark one notification as read.
- Mark all notifications as read.

## Permission test

- Confirm `/team` requires `team.view`.
- Confirm `/reports` requires `reports.view`.
- Confirm `/settings` requires `settings.view` or `settings.manage`.
- Confirm `/subscription` requires `subscription.view`.
- Confirm inactive users are redirected to `/unauthorized`.

## Subscription limit test

- Open `/subscription`.
- Confirm plan order is Starter, Professional, Business, Enterprise.
- Test seat limit with team invites if staging data allows.
- Test company limit if staging data allows.
- Test document size/storage validation if staging data allows.

## Final release check

- Run `npm run build`.
- Run `npm run typecheck`.
- Run `npm run lint`.
