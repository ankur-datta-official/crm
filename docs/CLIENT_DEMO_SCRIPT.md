# Client Demo Script

Use this script for a clean client-facing walkthrough of the CRM.

## 1. Login

1. Open the deployed CRM login page.
2. Sign in with the demo admin account.
3. Mention that access is role-based and tenant-scoped.

## 2. Dashboard overview

1. Open `/dashboard`.
2. Highlight:
   - total companies
   - total contacts
   - meetings this week
   - follow-up stats
   - open help requests
3. If visible, mention plan usage and active users.

## 3. Add company

1. Go to `/companies`.
2. Click `Add Company`.
3. Create a sample company lead.
4. Show filters, status, stage, and assigned owner.

## 4. Show pipeline board

1. Open `/pipeline`.
2. Point out the live Kanban stages, deal counts, and pipeline value by stage.
3. Drag the new company from an early stage to a later stage such as `Proposal Sent`.
4. Open the deal card actions and show quick links for company profile, meeting, and follow-up creation.
5. Mention that the board uses the same tenant-safe company and stage data as the rest of the CRM.

## 5. Add contact

1. Go to `/contacts`.
2. Click `Add Contact`.
3. Link the contact to the new company.
4. Mention primary contacts and relationship tracking.

## 6. Add meeting

1. Go to `/meetings`.
2. Click `Add Meeting`.
3. Record discussion notes, success rating, and next action.
4. Show that meeting history stays linked to the company.

## 7. Create follow-up

1. Go to `/followups`.
2. Click `Add Follow-up`.
3. Schedule a follow-up with priority and assignee.
4. Mention overdue, pending, and completed follow-up tracking.

## 8. Upload document

1. Go to `/documents`.
2. Click `Upload Document`.
3. Attach a small sample file.
4. Show document metadata, download support, and storage-aware limits.

## 9. Create Need Help request

1. Go to `/need-help`.
2. Click `New Help Request`.
3. Create a request tied to the company or follow-up.
4. Show assignment and resolution workflow.

## 10. View reports

1. Open `/reports`.
2. Walk through:
   - sales overview
   - pipeline metrics
   - meetings
   - follow-ups
   - help requests
3. Mention permission and subscription-based access where relevant.

## 11. Show team and roles

1. Open `/team`.
2. Show:
   - team members
   - invitations
   - roles and permissions
3. Mention invite links, role management, and deactivation/reactivation.

## 12. Show subscription plan limits

1. Open `/subscription`.
2. Highlight:
   - current plan
   - user usage
   - company usage
   - storage usage
   - feature availability
3. Mention that payment automation is intentionally out of scope in the current release.

## 13. Show global search

1. Use the topbar search.
2. Search for:
   - a company name
   - a contact email
   - meeting text
3. Open a result and show cross-module discoverability.

## 14. Show notifications

1. Open the notification bell.
2. Show unread count.
3. Click a notification and explain action-driven alerts.
4. Mention mark-as-read and mark-all-as-read.

## 15. Close the demo

1. Summarize the main workflow:
   - capture leads
   - move deals across the pipeline board
   - manage contacts
   - log meetings
   - track follow-ups
   - store documents
   - escalate internal help
   - report on team activity
2. Mention tenant isolation, permissions, and staged deployment readiness.
