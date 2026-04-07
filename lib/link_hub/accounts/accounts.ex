defmodule LinkHub.Accounts do
  @moduledoc "Ash domain for users, workspaces, memberships, and authentication."
  use Ash.Domain

  resources do
    resource LinkHub.Accounts.User do
      define(:register_with_password, args: [:email, :password, :password_confirmation])
      define(:sign_in_with_password, args: [:email, :password])
      define(:request_magic_link, args: [:email])
      define(:get_user_by_id, action: :read, get_by: [:id])
    end

    resource LinkHub.Accounts.Workspace do
      define(:create_workspace, action: :create, args: [:name])
      define(:get_workspace, action: :read, get_by: [:id])
    end

    resource LinkHub.Accounts.Membership do
      define(:create_membership, action: :create)
      define(:list_memberships, action: :read)
    end

    resource(LinkHub.Accounts.Token)
  end
end
