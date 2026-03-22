# Onboarding Flow Design

## Overview

Wire the existing 4-step onboarding (`/onboarding`) into the auth and app lifecycle. New users are redirected to onboarding after registration. Users without an org see a dismissible banner on the dashboard. Invite emails are sent via Swoosh with a generic signup link.

## Architecture

### 1. Remove org creation from RegisterLive

**Critical**: `RegisterLive` currently creates an org + membership during registration. This must be removed — org creation belongs in the onboarding flow. Registration should only create the user account, then redirect to `/onboarding`.

Changes to `register_live.ex`:
- Remove the `create_default_organisation` and membership creation logic
- Keep the redirect to `/onboarding` (already exists)

### 2. Onboarding completion detection

The `AssignDefaults` hook currently loads `current_user` from the session token. Extend it to also query for the user's org membership:

- After loading `current_user`, query `Membership` filtered by `user_id`
- If no membership exists → assign `onboarding_complete: false`
- If membership exists → assign `onboarding_complete: true`
- This assign is available to all LiveViews in the `:app` live_session

Note: `onboarding_complete` is per-user (do they have ANY org membership?), not per-org.

### 3. Dashboard banner

When `onboarding_complete == false`, render a full-width dismissible banner at the top of the dashboard:

- Full-width bar above page content
- Text: "Complete your workspace setup to get the most out of FounderPad"
- CTA button: "Complete Setup" linking to `/onboarding`
- X button to dismiss
- Dismissal sets a socket assign (`setup_banner_dismissed: true`) — resets on page refresh
- Banner does NOT reappear after LiveView navigation within the same session

### 4. Onboarding skip-if-done

In `OnboardingLive.mount`:

- If the user already has an org membership → redirect to `/dashboard` with flash "You've already completed onboarding"
- This prevents users from accidentally creating duplicate orgs
- Note: `/onboarding` is outside the `:app` live_session, so it must load `current_user` from the session token directly (already does this)

### 5. Invite emails

On "complete" (step 4), after creating the workspace:

- Iterate `invite_emails` list
- For each email, send via a new `InviteEmail` module using Swoosh
- Follow the existing `AuthMailer` pattern in `lib/founder_pad/notifications/auth_mailer.ex`
- Email contains:
  - Subject: "You've been invited to join [Org Name] on FounderPad"
  - Body: friendly invite message with org name and link to `/auth/register`
  - No token or magic link — just a generic signup URL
- Use `FounderPad.Mailer.deliver_later()` for async delivery
- Log each invite send via `FounderPad.Audit.log/6`

### 6. Validation hardening

- **Step 1**: Block "Continue" if org name is blank (disable button via assigns, show inline error)
- **Step 2**: Validate email format with basic check before adding to invite list; show error for invalid emails
- **create_workspace**: Replace bare `{:ok, _} =` pattern matches with proper `case` blocks to handle failures gracefully; return `{:error, reason}` on any step failure with rollback

## Files

| File | Action | Description |
|------|--------|-------------|
| `lib/founder_pad_web/live/auth/register_live.ex` | Modify | Remove org + membership creation, keep redirect to /onboarding |
| `lib/founder_pad_web/hooks/assign_defaults.ex` | Modify | Add org membership query, set `onboarding_complete` assign |
| `lib/founder_pad_web/live/onboarding_live.ex` | Modify | Add skip-if-done redirect, input validation, send invite emails on complete |
| `lib/founder_pad_web/live/dashboard_live.ex` | Modify | Add dismissible setup banner when `onboarding_complete == false` |
| `lib/founder_pad/accounts/emails/invite_email.ex` | Create | Swoosh email template for team invites |
| `test/founder_pad_web/live/onboarding_live_test.exs` | Create | Tests for full onboarding flow |

## Data Flow

```
Registration (user account only) → /auth/session?redirect_to=/onboarding → /onboarding
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
  4. Send invite emails (async via Mailer.deliver_later)
  5. Audit log the onboarding completion
  6. Redirect to /agents/:id or /dashboard
```

## Testing Strategy

- **Skip-if-done**: User with existing membership → redirected to /dashboard
- **Validation**: Blank org name blocked at step 1; invalid email rejected at step 2
- **Happy path**: Full flow creates org, membership, agent; invites sent
- **No agent**: Completing without selecting a template → redirects to /dashboard
- **Invite emails**: Verify mailer called with correct recipient and org name
- **Banner**: Dashboard shows banner when no org; dismisses on click; hidden when org exists
- **Registration**: Verify registration no longer creates org/membership
