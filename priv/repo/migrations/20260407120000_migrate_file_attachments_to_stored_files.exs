defmodule LinkHub.Repo.Migrations.MigrateFileAttachmentsToStoredFiles do
  @moduledoc """
  Data migration: copies existing file_attachments records into stored_files.
  Creates corresponding file_contexts for any message-linked attachments.
  Does NOT delete file_attachments — they remain for backwards compatibility.
  """
  use Ecto.Migration

  def up do
    execute("""
    INSERT INTO stored_files (id, filename, content_type, size_bytes, storage_key, status, virus_scan_status, metadata, workspace_id, uploader_id, inserted_at, updated_at)
    SELECT id, filename, content_type, size_bytes, storage_path, 'ready', 'clean', '{}', workspace_id, uploader_id, inserted_at, updated_at
    FROM file_attachments
    ON CONFLICT DO NOTHING
    """)

    execute("""
    INSERT INTO file_contexts (id, context_type, stored_file_id, message_id, inserted_at, updated_at)
    SELECT gen_random_uuid(), 'message', id, message_id, inserted_at, updated_at
    FROM file_attachments
    WHERE message_id IS NOT NULL
    ON CONFLICT DO NOTHING
    """)
  end

  def down do
    execute("DELETE FROM file_contexts WHERE stored_file_id IN (SELECT id FROM file_attachments)")
    execute("DELETE FROM stored_files WHERE id IN (SELECT id FROM file_attachments)")
  end
end
