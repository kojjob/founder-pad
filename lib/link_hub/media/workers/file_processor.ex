defmodule LinkHub.Media.Workers.FileProcessor do
  @moduledoc """
  Processes uploaded files asynchronously:
  1. Virus scan
  2. Image metadata extraction
  3. Thumbnail generation (for images)
  4. Status update to :ready or :failed
  """
  use Oban.Worker, queue: :media, max_attempts: 3

  require Logger
  require Ash.Query

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"file_id" => file_id}}) do
    case Ash.get(LinkHub.Media.StoredFile, file_id) do
      {:ok, file} ->
        process_file(file)

      {:error, reason} ->
        if not_found?(reason) do
          Logger.warning("FileProcessor: file #{file_id} not found, skipping")
          :ok
        else
          Logger.error("FileProcessor: failed to fetch file #{file_id}: #{inspect(reason)}")
          {:error, reason}
        end
    end
  end

  defp process_file(file) do
    file =
      file
      |> Ash.Changeset.for_update(:mark_processing)
      |> Ash.update!()

    with {:ok, file} <- run_virus_scan(file),
         {:ok, file} <- extract_metadata(file),
         {:ok, file} <- generate_thumbnail(file) do
      file
      |> Ash.Changeset.for_update(:mark_ready, %{
        metadata: file.metadata,
        thumbnail_key: file.thumbnail_key
      })
      |> Ash.update!()

      Logger.info("FileProcessor: completed processing #{file.id}")
      :ok
    else
      {:error, :infected} ->
        file
        |> Ash.Changeset.for_update(:mark_failed, %{
          metadata: Map.put(file.metadata, "error", "virus_detected")
        })
        |> Ash.update!()

        Logger.warning("FileProcessor: virus detected in #{file.id}")
        :ok

      {:error, reason} ->
        file
        |> Ash.Changeset.for_update(:mark_failed, %{
          metadata: Map.put(file.metadata, "error", inspect(reason))
        })
        |> Ash.update!()

        Logger.error("FileProcessor: failed processing #{file.id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp run_virus_scan(file) do
    # VirusScan expects a file path — in production, download from storage first.
    # The stub adapter ignores the path and returns :clean.
    scan_result =
      case LinkHub.Media.VirusScan.scan(file.storage_key) do
        {:ok, :clean} -> :clean
        {:ok, :infected} -> :infected
        {:error, _} -> :error
      end

    file =
      file
      |> Ash.Changeset.for_update(:set_virus_scan, %{scan_result: scan_result})
      |> Ash.update!()

    case scan_result do
      :clean -> {:ok, file}
      :infected -> {:error, :infected}
      :error -> {:ok, file}
    end
  end

  defp extract_metadata(file) do
    if image?(file.content_type) do
      case extract_image_metadata(file.storage_key) do
        {:ok, image_meta} ->
          metadata = Map.merge(file.metadata, image_meta)
          {:ok, %{file | metadata: metadata}}

        {:error, reason} ->
          Logger.warning(
            "FileProcessor: metadata extraction failed for #{file.id}: #{inspect(reason)}"
          )

          {:ok, file}
      end
    else
      {:ok, file}
    end
  end

  defp generate_thumbnail(file) do
    if image?(file.content_type) do
      thumbnail_key = "thumbnails/#{file.id}_thumb.jpg"
      {:ok, _} = generate_image_thumbnail(file.storage_key, thumbnail_key)
      {:ok, %{file | thumbnail_key: thumbnail_key}}
    else
      {:ok, file}
    end
  end

  defp extract_image_metadata(_storage_key) do
    # TODO: download from storage and use Mogrify.verbose/1
    {:ok, %{}}
  end

  defp generate_image_thumbnail(_source_key, _thumbnail_key) do
    # TODO: download from storage, resize with Mogrify, upload thumbnail
    {:ok, :skipped}
  end

  defp image?(content_type) do
    String.starts_with?(content_type || "", "image/")
  end

  defp not_found?(%Ash.Error.Invalid{errors: errors}) do
    Enum.any?(errors, &match?(%Ash.Error.Query.NotFound{}, &1))
  end

  defp not_found?(_), do: false
end
