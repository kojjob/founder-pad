defmodule LinkHub.Messaging do
  @moduledoc "Ash domain for channels, messages, reactions, and read receipts."
  use Ash.Domain

  resources do
    resource LinkHub.Messaging.Channel do
      define(:create_channel, action: :create)
      define(:get_channel, action: :read, get_by: [:id])
      define(:list_channels, action: :list_by_workspace)
      define(:archive_channel, action: :archive)
    end

    resource LinkHub.Messaging.ChannelMembership do
      define(:join_channel, action: :join)
      define(:leave_channel, action: :leave, args: [:channel_id, :user_id])
      define(:list_channel_members, action: :read)
    end

    resource LinkHub.Messaging.Message do
      define(:send_message, action: :send)
      define(:edit_message, action: :edit)
      define(:delete_message, action: :soft_delete)
      define(:list_messages, action: :list_by_channel)
      define(:get_message, action: :read, get_by: [:id])
    end

    resource LinkHub.Messaging.Reaction do
      define(:add_reaction, action: :add)
      define(:remove_reaction, action: :remove)
    end

    resource LinkHub.Messaging.ReadReceipt do
      define(:mark_read, action: :mark)
    end
  end
end
