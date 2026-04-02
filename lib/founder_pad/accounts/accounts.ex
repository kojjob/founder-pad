defmodule FounderPad.Accounts do
  use Ash.Domain

  resources do
    resource FounderPad.Accounts.User do
      define :register_with_password, args: [:email, :password, :password_confirmation]
      define :sign_in_with_password, args: [:email, :password]
      define :request_magic_link, args: [:email]
      define :get_user_by_id, action: :read, get_by: [:id]
      define :suspend_user, action: :suspend
      define :unsuspend_user, action: :unsuspend
      define :list_all_users, action: :list_all
    end

    resource FounderPad.Accounts.Organisation do
      define :create_organisation, action: :create, args: [:name]
      define :get_organisation, action: :read, get_by: [:id]
    end

    resource FounderPad.Accounts.Membership do
      define :create_membership, action: :create
      define :list_memberships, action: :read
    end

    resource FounderPad.Accounts.Token
  end
end
