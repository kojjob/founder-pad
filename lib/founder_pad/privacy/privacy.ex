defmodule FounderPad.Privacy do
  use Ash.Domain

  resources do
    resource FounderPad.Privacy.CookieConsent do
      define(:create_cookie_consent, action: :create)
      define(:update_cookie_consent, action: :update)
    end

    resource FounderPad.Privacy.DataExportRequest do
      define(:create_export_request, action: :create)
      define(:mark_export_completed, action: :mark_completed)
      define(:mark_export_failed, action: :mark_failed)
      define(:list_exports_by_user, action: :by_user, args: [:user_id])
    end

    resource FounderPad.Privacy.DeletionRequest do
      define(:create_deletion_request, action: :create)
      define(:confirm_deletion, action: :confirm)
      define(:execute_soft_delete, action: :execute_soft_delete)
      define(:cancel_deletion, action: :cancel)
    end
  end
end
