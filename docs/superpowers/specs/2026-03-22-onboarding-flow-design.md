# Onboarding Flow Design

## Overview

Wire the existing 4-step onboarding (`/onboarding`) into the auth and app lifecycle. New users are redirected to onboarding after registration. Users without an org see a dismissible banner on the dashboard. Invite emails are sent via Swoosh with a generic signup link.

## Architecture

### 1. Post-registration redirect

Registration already redirects to `/onboarding` via `redirect_to=%2Fonboarding` in the auth session URL. No change needed.

### 2. Onboarding completion detection

The `AssignDefaults` hook currently loads `current_user` from the session token. Extend it to also query for the user's org membership:

- After loading `current_user`, query `Membership` filtered by `user_id`
- If no membership exists → assign `onboarding_complete: false`
- If membership exists → assign `onboarding_complete: true`
- This assign is available to all LiveViews in the `:app` live_session

### 3. Dashboard banner

When `onboarding_complete == false`, render a full-width dismissible banner at the top of the dashboard:

- Full-width bar above page content
- Text: "Complete your workspace setup to get the most out of FounderPad"
- CTA button: "Complete Setup" linking to `/onboarding`
- X button to dismiss
- Dismissal sets a session-level assign (`setup_banner_dismissed: true`) so it doesn't reappear during the current LiveView session
- Banner does NOT reappear after page navigation within the same session

### 4. Onboarding skip-if-done

In `OnboardingLive.mount`:

- If the user already has an org membership → redirect to `/dashboard` with flash "You've already completed onboarding"
- This prevents users from accidentally creating duplicate orgs

### 5. Invite emails

On "complete" (step 4), after creating the workspace:

- Iterate `invite_emails` list
- For each email, send via a new `InviteMailer` module using Swoosh
- Email contains:
  - Subject: "You've been invited to join [Org Name] on FounderPad"
  - Body: friendly invite message with org name and link to `/auth/register`
  - No token or magic link — just a generic signup URL
- Emails sent async via `deliver_later` to not block the completion
- Log each invite send for audit trail

### 6. Validation hardening

- **Step 1**: Block "Continue" if org name is blank (disable button + show inline error)
- **Step 2**: Validate email format with regex before adding to invite list; show error for invalid emails
- **create_workspace**: Replace bare `{:ok, _} =` pattern matches with proper `case` blocks to handle failures gracefully

## Files

| File | Action | Description |
|------|--------|-------------|
| `lib/founder_pad_web/hooks/assign_defaults.ex` | Modify | Add org membership query, set `onboarding_complete` assign |
| `lib/founder_pad_web/live/onboarding_live.ex` | Modify | Add skip-if-done redirect, input validation, send invite emails on complete |
| `lib/founder_pad_web/live/dashboard_live.ex` | Modify | Add dismissible setup banner when `onboarding_complete == false` |
| `lib/founder_pad/accounts/emails/invite_email.ex` | Create | Swoosh email template for team invites |
| `test/founder_pad_web/live/onboarding_live_test.exs` | Create | Tests: skip-if-done, validation, org+membership creation, invite sending |

## Data Flow

```
Registration → /auth/session?redirect_to=/onboarding → /onboarding
    ↓
Step 1: Enter org name (validated non-blank)
    ↓
Step 2: Add invite emails (validated format)
    ↓
Step 3: Select agent template (optional)
    ↓
Step 4: Summary → "Go to Dashboard" button
    ↓
complete event:
  1. Create Organisation
  2. Create Membership (owner)
  3. Create Agent from template (if selected)
  4. Send invite emails (async)
  5. Redirect to /agents/:id or /dashboard
```

## Testing Strategy

- **Skip-if-done**: User with existing membership → redirected to /dashboard
- **Validation**: Blank org name blocked at step 1; invalid email rejected at step 2
- **Happy path**: Full flow creates org, membership, agent, and enqueues invite emails
- **No agent**: Completing without selecting a template → redirects to /dashboard
- **Invite emails**: Verify mailer called with correct recipient and org name
- **Banner**: Dashboard shows banner when no org; dismisses on click; hidden when org exists
