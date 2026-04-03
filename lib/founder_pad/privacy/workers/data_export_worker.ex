defmodule FounderPad.Privacy.Workers.DataExportWorker do
  @moduledoc "Oban worker that collects user data and generates a JSON export."
  use Oban.Worker, queue: :default, max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"export_request_id" => request_id, "user_id" => user_id}}) do
    request = Ash.get!(FounderPad.Privacy.DataExportRequest, request_id)

    try do
      user = Ash.get!(FounderPad.Accounts.User, user_id)

      user_data = %{
        profile: %{
          email: to_string(user.email),
          name: user.name,
          created_at: to_string(user.inserted_at)
        },
        preferences: user.preferences,
        email_preferences: user.email_preferences,
        exported_at: DateTime.utc_now() |> to_string()
      }

      file_name = "user_export_#{user_id}_#{System.system_time(:second)}.json"

      file_path =
        Path.join([
          Application.app_dir(:founder_pad, "priv"),
          "static",
          "exports",
          file_name
        ])

      File.mkdir_p!(Path.dirname(file_path))
      File.write!(file_path, Jason.encode!(user_data, pretty: true))

      request
      |> Ash.Changeset.for_update(:mark_completed, %{file_path: "/exports/#{file_name}"})
      |> Ash.update!()

      :ok
    rescue
      e ->
        request
        |> Ash.Changeset.for_update(:mark_failed, %{error: Exception.message(e)})
        |> Ash.update!()

        {:error, Exception.message(e)}
    end
  end
end
