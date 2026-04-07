defmodule LinkHub.Media do
  @moduledoc "Ash domain for file attachments and media storage."
  use Ash.Domain

  resources do
    resource LinkHub.Media.FileAttachment do
      define(:create_attachment, action: :create)
      define(:get_attachment, action: :read, get_by: [:id])
      define(:list_attachments_for_message, action: :list_by_message)
      define(:search, action: :search)
    end

    resource LinkHub.Media.StoredFile do
      define(:upload_file, action: :upload)
      define(:get_stored_file, action: :read, get_by: [:id])
      define(:list_files_by_workspace, action: :list_by_workspace)
      define(:list_ready_files, action: :list_ready_by_workspace)
      define(:search_files, action: :search)
    end

    resource LinkHub.Media.StorageQuota do
      define(:create_quota, action: :create)
      define(:get_quota_by_workspace, action: :get_by_workspace)
    end

    resource(LinkHub.Media.FileContext)

    resource(LinkHub.Media.ShareLink)
  end
end
