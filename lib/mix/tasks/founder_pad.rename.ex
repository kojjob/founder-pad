defmodule Mix.Tasks.FounderPad.Rename do
  @moduledoc """
  Renames the FounderPad boilerplate to your chosen app name.

  This task performs a full project rename, replacing all occurrences of
  "FounderPad" and "founder_pad" with your chosen PascalCase and snake_case
  names throughout the codebase, including module names, file paths, config
  keys, and atoms.

  ## Usage

      mix founder_pad.rename MyApp my_app

  ## Arguments

    * `PascalCase` - The new module name (e.g., "MyApp", "AcmeSaas")
    * `snake_case` - The new app/file name (e.g., "my_app", "acme_saas")

  ## What it does

    1. Replaces module names: `FounderPad` → `MyApp`, `FounderPadWeb` → `MyAppWeb`
    2. Replaces app names: `founder_pad` → `my_app`, `founder_pad_web` → `my_app_web`
    3. Renames files and directories containing `founder_pad`
    4. Updates config files including mix.exs, config/*.exs, and branding.exs
    5. Prints a summary of all changes and next steps

  ## Important

  **Back up your project before running this task.** The changes are
  irreversible and touch nearly every file in the project.

      cp -r my_project my_project_backup
      cd my_project
      mix founder_pad.rename MyApp my_app
  """

  use Mix.Task

  @shortdoc "Rename the boilerplate to your app name"

  @ignored_dirs ~w(.git _build deps node_modules .elixir_ls .lexical priv/static/uploads priv/static/assets)
  @binary_extensions ~w(.png .jpg .jpeg .gif .ico .svg .woff .woff2 .ttf .eot .zip .gz .tar .beam .ez)

  @impl Mix.Task
  def run(args) do
    case validate_args(args) do
      {:ok, pascal, snake} ->
        perform_rename(pascal, snake)

      {:error, message} ->
        Mix.shell().error(message)
        Mix.shell().info("\nUsage: mix founder_pad.rename MyApp my_app")
    end
  end

  defp validate_args([pascal, snake | _rest]) do
    cond do
      not Regex.match?(~r/^[A-Z][a-zA-Z0-9]*$/, pascal) ->
        {:error, "Error: First argument must be PascalCase (e.g., MyApp). Got: #{pascal}"}

      not Regex.match?(~r/^[a-z][a-z0-9]*(_[a-z0-9]+)*$/, snake) ->
        {:error, "Error: Second argument must be snake_case (e.g., my_app). Got: #{snake}"}

      expected_snake(pascal) != snake ->
        {:error,
         "Error: snake_case name '#{snake}' does not match PascalCase name '#{pascal}'. " <>
           "Expected '#{expected_snake(pascal)}'."}

      pascal == "FounderPad" ->
        {:error, "Error: New name cannot be the same as the current name 'FounderPad'."}

      true ->
        {:ok, pascal, snake}
    end
  end

  defp validate_args(_) do
    {:error, "Error: Expected exactly 2 arguments."}
  end

  defp expected_snake(pascal) do
    pascal
    |> String.replace(~r/([A-Z])/, "_\\1")
    |> String.trim_leading("_")
    |> String.downcase()
  end

  defp perform_rename(pascal, snake) do
    Mix.shell().info("""
    \n========================================
    FounderPad Rename Tool
    ========================================

    Renaming project:
      FounderPad    → #{pascal}
      founder_pad   → #{snake}
      FounderPadWeb → #{pascal}Web
      founder_pad_web → #{snake}_web

    WARNING: This operation modifies files in-place.
    Make sure you have a backup or clean git state.
    ========================================
    """)

    root = File.cwd!()

    replacements = [
      {"FounderPadWeb", "#{pascal}Web"},
      {"founder_pad_web", "#{snake}_web"},
      {"FounderPad", pascal},
      {"founder_pad", snake}
    ]

    # Phase 1: Replace file contents
    Mix.shell().info("Phase 1: Replacing file contents...")
    files = collect_files(root)
    content_count = replace_in_files(files, replacements)
    Mix.shell().info("  Updated content in #{content_count} files.")

    # Phase 2: Rename files and directories (deepest paths first)
    Mix.shell().info("\nPhase 2: Renaming files and directories...")
    rename_count = rename_paths(root, replacements)
    Mix.shell().info("  Renamed #{rename_count} files/directories.")

    # Summary
    total = content_count + rename_count

    Mix.shell().info("""
    \n========================================
    Rename complete!
    ========================================

    Total changes: #{total} (#{content_count} file contents + #{rename_count} path renames)

    Next steps:
      1. Review the changes:
           git diff

      2. Update your database:
           mix ecto.drop
           mix ecto.create
           mix ecto.migrate

      3. Install dependencies (app name changed in mix.exs):
           mix deps.get
           cd assets && npm install && cd ..

      4. Verify everything compiles:
           mix compile

      5. Run the test suite:
           mix test

      6. Start the server:
           mix phx.server

      7. Commit your renamed project:
           git add -A
           git commit -m "chore: rename FounderPad to #{pascal}"

    ========================================
    """)
  end

  defp collect_files(root) do
    root
    |> Path.join("**/*")
    |> Path.wildcard(match_dot: false)
    |> Enum.reject(&File.dir?/1)
    |> Enum.reject(&ignored_path?(&1, root))
    |> Enum.reject(&binary_file?/1)
  end

  defp ignored_path?(path, root) do
    relative = Path.relative_to(path, root)

    Enum.any?(@ignored_dirs, fn dir ->
      String.starts_with?(relative, dir <> "/") or relative == dir
    end)
  end

  defp binary_file?(path) do
    ext = Path.extname(path) |> String.downcase()
    ext in @binary_extensions
  end

  defp replace_in_files(files, replacements) do
    Enum.reduce(files, 0, fn file, count ->
      case File.read(file) do
        {:ok, content} ->
          new_content = apply_replacements(content, replacements)

          if new_content != content do
            File.write!(file, new_content)
            count + 1
          else
            count
          end

        {:error, _} ->
          count
      end
    end)
  end

  defp apply_replacements(content, replacements) do
    Enum.reduce(replacements, content, fn {from, to}, acc ->
      String.replace(acc, from, to)
    end)
  end

  defp rename_paths(root, replacements) do
    # Collect all paths, sort by depth (deepest first) so we rename
    # children before parents
    paths =
      root
      |> Path.join("**/*")
      |> Path.wildcard(match_dot: false)
      |> Enum.reject(&ignored_path?(&1, root))
      |> Enum.sort_by(&(-String.length(&1)))

    Enum.reduce(paths, 0, fn path, count ->
      basename = Path.basename(path)
      new_basename = apply_replacements(basename, replacements)

      if new_basename != basename do
        new_path = Path.join(Path.dirname(path), new_basename)

        if File.exists?(path) and not File.exists?(new_path) do
          File.rename!(path, new_path)
          count + 1
        else
          count
        end
      else
        count
      end
    end)
  end
end
