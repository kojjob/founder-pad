# Library Research: File Transfer Service

## Recommended

### ex_aws

- **Hex**: https://hex.pm/packages/ex_aws
- **Docs**: https://hexdocs.pm/ex_aws
- **Downloads**: Millions (one of the most downloaded Elixir libraries)
- **Last release**: 2.6.1 (actively maintained)
- **Why**: Core AWS client required by ex_aws_s3. Handles credential chain, request signing, retry logic, and HTTP dispatch. Wraps all AWS services behind a unified `ExAws.request/2` interface.

**mix.exs:**
```elixir
{:ex_aws, "~> 2.5"},
{:hackney, "~> 1.9"},
{:sweet_xml, "~> 0.7"},
```

**config/config.exs** (defaults for all envs):
```elixir
config :ex_aws,
  json_codec: Jason,
  normalize_path: false,
  retries: [
    max_attempts: 3,
    base_backoff_in_ms: 100,
    max_backoff_in_ms: 5_000
  ]

# S3-specific config
config :ex_aws, :s3,
  scheme: "https://",
  region: "us-east-1"
```

**config/runtime.exs** (secrets injected at runtime — never hardcode in config.exs):
```elixir
config :ex_aws,
  access_key_id: [
    {:system, "AWS_ACCESS_KEY_ID"},
    :instance_role
  ],
  secret_access_key: [
    {:system, "AWS_SECRET_ACCESS_KEY"},
    :instance_role
  ],
  region: System.get_env("AWS_REGION") || "us-east-1"
```

**Credential chain resolution order:**
1. `{:system, "ENV_VAR"}` — reads env var at runtime
2. `{:awscli, "profile_name", timeout_ms}` — reads `~/.aws/credentials` (requires `configparser_ex` dep)
3. `:pod_identity` — EKS Pod Identity
4. `:instance_role` — EC2/ECS IAM role (fetches from metadata endpoint)

**Session token (for assumed roles / temporary credentials):**
```elixir
config :ex_aws,
  security_token: [{:system, "AWS_SESSION_TOKEN"}, :instance_role]
```

**Hackney options:**
```elixir
config :ex_aws, :hackney_opts,
  recv_timeout: 30_000,
  connect_timeout: 5_000
```

**Gotchas:**
- `normalize_path: false` is required for S3 key paths that contain special characters or dots — without it, S3 signatures break on paths like `folder/../file.jpg`
- The credential list is tried in order; use `[{:system, "VAR"}, :instance_role]` so local dev uses env vars and prod uses IAM role automatically
- Do NOT hardcode `access_key_id: "AKIA..."` strings in config files; they will end up in version control

---

### ex_aws_s3

- **Hex**: https://hex.pm/packages/ex_aws_s3
- **Docs**: https://hexdocs.pm/ex_aws_s3
- **Downloads**: Millions
- **Last release**: 2.5.9 (actively maintained)
- **Why**: S3-specific operations. Generates `ExAws.Operation.S3` structs that are then executed via `ExAws.request/2`. Presigned URL generation is client-side only (no HTTP request needed).

**Key function signatures:**

#### Presigned URLs

```elixir
# Full signature
ExAws.S3.presigned_url(
  config :: map(),        # ExAws.Config.new(:s3)
  http_method :: atom(),  # :get | :put | :post | :delete | :head
  bucket :: binary(),
  object :: binary(),
  opts :: [
    expires_in: integer(),         # seconds; AWS default is 3600
    virtual_host: boolean(),       # use <bucket>.s3.<region>.amazonaws.com
    s3_accelerate: boolean(),      # use S3 Transfer Acceleration endpoint
    query_params: [{binary(), binary()}],  # extra query params to sign
    headers: [{binary(), binary()}],       # headers to include in signature
    bucket_as_host: boolean(),     # bucket is the full hostname (CDN use case)
    start_datetime: NaiveDateTime.t()      # shift the signing window (caching)
  ]
) :: {:ok, binary()} | {:error, binary()}
```

**Presigned PUT (client uploads directly to S3):**
```elixir
config = ExAws.Config.new(:s3)

{:ok, url} =
  ExAws.S3.presigned_url(config, :put, "my-bucket", "uploads/#{key}",
    expires_in: 900,  # 15 minutes
    headers: [{"content-type", "image/jpeg"}]
  )
```

When restricting content-type on a presigned PUT, the client MUST send the exact same `Content-Type` header in their upload request — otherwise S3 rejects with `SignatureDoesNotMatch`.

**Presigned GET (time-limited download):**
```elixir
{:ok, url} =
  ExAws.S3.presigned_url(config, :get, "my-bucket", "uploads/#{key}",
    expires_in: 3600,
    query_params: [
      {"response-content-disposition", "attachment; filename=\"#{filename}\""},
      {"response-content-type", "application/octet-stream"}
    ]
  )
```

The `response-content-disposition` and `response-content-type` query params override the stored S3 metadata headers in the response — useful for forcing browser download.

#### Server-Side Upload

```elixir
# put_object/4 signature
ExAws.S3.put_object(
  bucket :: binary(),
  object :: binary(),
  body :: binary(),
  opts :: [
    content_type: binary(),
    content_length: integer(),
    content_disposition: binary(),
    acl: binary(),                # "private" | "public-read" | etc.
    encryption: binary(),         # "AES256" | "aws:kms"
    meta: [{binary(), binary()}], # x-amz-meta-* headers
    storage_class: binary(),      # "STANDARD" | "STANDARD_IA" | "GLACIER"
    tagging: binary(),            # URL-encoded tag string
    cache_control: binary()
  ]
) :: ExAws.Operation.S3.t()

# Execute it:
ExAws.S3.put_object("my-bucket", "uploads/#{key}", binary_data,
  content_type: "image/jpeg",
  acl: "private"
)
|> ExAws.request()
```

#### delete_object/3

```elixir
ExAws.S3.delete_object(
  bucket :: binary(),
  object :: binary(),
  opts :: [
    version_id: binary()
  ]
) :: ExAws.Operation.S3.t()

ExAws.S3.delete_object("my-bucket", "uploads/#{key}") |> ExAws.request()
```

#### head_object/3 (check existence / get metadata without downloading)

```elixir
ExAws.S3.head_object(
  bucket :: binary(),
  object :: binary(),
  opts :: [
    version_id: binary(),
    range: binary(),
    if_modified_since: binary(),
    if_unmodified_since: binary(),
    if_match: binary(),          # ETag match
    if_none_match: binary()
  ]
) :: ExAws.Operation.S3.t()

# Returns {:ok, %{headers: [...]}} or {:error, {:http_error, 404, _}}
case ExAws.S3.head_object("my-bucket", "uploads/#{key}") |> ExAws.request() do
  {:ok, %{headers: headers}} ->
    content_length = List.keyfind(headers, "content-length", 0) |> elem(1)
    {:ok, String.to_integer(content_length)}
  {:error, {:http_error, 404, _}} ->
    {:error, :not_found}
  {:error, reason} ->
    {:error, reason}
end
```

#### Multipart Upload (for files > 5 MB or unknown size)

```elixir
# Step 1: initiate
{:ok, %{body: %{upload_id: upload_id}}} =
  ExAws.S3.initiate_multipart_upload("my-bucket", "uploads/#{key}",
    content_type: "video/mp4"
  )
  |> ExAws.request()

# Step 2: upload each part (minimum 5 MB except last part)
{:ok, %{headers: headers}} =
  ExAws.S3.upload_part("my-bucket", "uploads/#{key}", upload_id, 1, chunk_binary)
  |> ExAws.request()
etag = List.keyfind(headers, "ETag", 0) |> elem(1)

# Step 3: complete
ExAws.S3.complete_multipart_upload("my-bucket", "uploads/#{key}", upload_id,
  [{1, etag}]  # list of {part_number, etag}
)
|> ExAws.request()

# Or abort on failure
ExAws.S3.abort_multipart_upload("my-bucket", "uploads/#{key}", upload_id)
|> ExAws.request()
```

**High-level streaming upload** (for large files from disk/stream):
```elixir
# upload/4 handles multipart automatically
File.stream!("large_file.mp4", [], 5 * 1024 * 1024)
|> ExAws.S3.upload("my-bucket", "uploads/#{key}",
  content_type: "video/mp4",
  max_concurrency: 4,
  timeout: :infinity
)
|> ExAws.request()
```

**Gotchas:**
- `presigned_url/5` first arg is a config MAP, not an atom. Use `ExAws.Config.new(:s3)` or `ExAws.Config.new(:s3, region: "eu-west-1")` to build it.
- presigned URLs are computed client-side — no HTTP request is made during generation
- For GET presigned URLs on private objects, the `Content-Type` in the stored object metadata does NOT restrict what content-type the response sends — use `response-content-type` query param to override
- Multipart parts must be ≥ 5 MB except for the final part
- ETags from AWS are quoted strings like `"abc123"` — preserve the quotes when passing to `complete_multipart_upload`

---

### hackney

- **Hex**: https://hex.pm/packages/hackney
- **Docs**: https://hexdocs.pm/hackney
- **Downloads**: Hundreds of millions (ubiquitous transitive dep)
- **Last release**: 1.25.0 / 3.2.1 (actively maintained — two tracks)
- **Why**: Required HTTP adapter for ex_aws. ExAws does not work with Req/Finch out of the box — it has a specific adapter interface and hackney is the default supported client.

**mix.exs:**
```elixir
{:hackney, "~> 1.9"}
```

Use the `~> 1.9` constraint (not `~> 3.x`) — the 3.x branch is a rewrite that ex_aws may not yet support. Pin to 1.x for compatibility.

**config/config.exs:**
```elixir
config :ex_aws, :hackney_opts,
  recv_timeout: 30_000,   # 30s for large file uploads
  connect_timeout: 5_000
```

**Gotchas:**
- hackney is a transitive dependency of many libraries — `mix deps.tree` will show if a version conflict exists
- No application config needed beyond hackney_opts; ex_aws picks it up automatically
- Do NOT add hackney to `extra_applications` — it starts itself

---

### sweet_xml

- **Hex**: https://hex.pm/packages/sweet_xml
- **Docs**: https://hexdocs.pm/sweet_xml
- **Downloads**: Tens of millions
- **Last release**: 0.7.5 (stable, low churn — XML parsing is mature)
- **Why**: Required by ex_aws_s3 to parse XML responses from the S3 API. S3 returns XML for list operations, error responses, and multipart upload initiation. Without sweet_xml, ex_aws_s3 cannot parse S3 responses.

**mix.exs:**
```elixir
{:sweet_xml, "~> 0.7"}
```

**No application config needed** — it's used as a dependency of ex_aws_s3 internally.

**Key functions (if you ever parse S3 XML manually):**
```elixir
import SweetXml

# Extract single value
xml |> xpath(~x"//Key/text()"s)   # s modifier = string (not charlist)

# Extract list
xml |> xpath(~x"//Contents"l, key: ~x"./Key/text()"s)

# Extract map
xml |> xmap(
  bucket: ~x"//Name/text()"s,
  keys: [~x"//Contents"l, key: ~x"./Key/text()"s]
)
```

**Gotchas:**
- Without the `s` modifier on `~x"..."s`, results are charlists `[107, 101, 121]` not strings
- sweet_xml wraps `:xmerl` — large XML documents are parsed into memory; use `stream_tags/3` for very large S3 list responses
- This is an infrastructure dependency only; do not `import SweetXml` in application code

---

### mogrify

- **Hex**: https://hex.pm/packages/mogrify
- **Docs**: https://hexdocs.pm/mogrify
- **Downloads**: ~3 million
- **Last release**: 0.9.3 (stable)
- **Why**: ImageMagick wrapper for thumbnail generation, format conversion, and image metadata extraction. The only maintained Elixir library for server-side image processing without a native NIF dependency.

**System requirement:** ImageMagick must be installed on the host.
```bash
# macOS
brew install imagemagick

# Debian/Ubuntu
apt-get install -y imagemagick

# Dockerfile
RUN apt-get install -y imagemagick
```

**mix.exs:**
```elixir
{:mogrify, "~> 0.9"}
```

**No application config needed.**

**Key function signatures:**

```elixir
# Mogrify.Image struct fields (populated after verbose/1)
%Mogrify.Image{
  path: binary(),
  ext: binary(),
  format: binary(),     # "jpeg", "png", "gif", "webp"
  width: integer(),
  height: integer(),
  animated: boolean(),
  frame_count: integer(),
  operations: keyword(),
  dirty: map()
}
```

**Open and inspect:**
```elixir
# open/1 initializes the struct but does NOT read metadata
image = Mogrify.open("path/to/image.jpg")

# verbose/1 populates width, height, format, animated fields
image = Mogrify.open("path/to/image.jpg") |> Mogrify.verbose()
# => %Mogrify.Image{width: 1920, height: 1080, format: "jpeg", ...}
```

**Thumbnail generation pipeline:**
```elixir
# resize_to_limit: fits within dimensions, preserves aspect ratio, no crop
Mogrify.open(source_path)
|> Mogrify.resize_to_limit("400x400")
|> Mogrify.format("jpeg")
|> Mogrify.save(path: dest_path)

# resize_to_fill: fills exact dimensions, crops excess
Mogrify.open(source_path)
|> Mogrify.resize_to_fill("200x200")
|> Mogrify.format("jpeg")
|> Mogrify.save(path: dest_path)
```

**Format conversion:**
```elixir
# Convert PNG to WebP
Mogrify.open("image.png")
|> Mogrify.format("webp")
|> Mogrify.save(path: "image.webp")
```

**identify/1 for basic metadata (no ImageMagick subprocess for format/dimensions):**
```elixir
# Returns %Mogrify.Image{} with metadata populated
info = Mogrify.identify("path/to/image.jpg")
# For specific attributes:
Mogrify.identify("path/to/image.jpg", format: "'%[orientation]'")
```

**Processing pipeline pattern:**
```elixir
defmodule LinkHub.Media.ImageProcessor do
  @thumbnail_sizes %{
    small: "100x100",
    medium: "400x400",
    large: "1200x1200"
  }

  def generate_thumbnail(source_path, size) when size in [:small, :medium, :large] do
    dimensions = Map.fetch!(@thumbnail_sizes, size)
    dest_path = thumbnail_path(source_path, size)

    Mogrify.open(source_path)
    |> Mogrify.resize_to_limit(dimensions)
    |> Mogrify.format("jpeg")
    |> Mogrify.save(path: dest_path)

    {:ok, dest_path}
  rescue
    e -> {:error, Exception.message(e)}
  end

  def image_info(path) do
    image = Mogrify.open(path) |> Mogrify.verbose()
    {:ok, %{width: image.width, height: image.height, format: image.format}}
  rescue
    e -> {:error, Exception.message(e)}
  end
end
```

**Gotchas:**
- `open/1` does NOT stat or read the file; it just builds the struct. `verbose/1` executes `mogrify -verbose` subprocess to populate dimensions/format.
- `save/2` with no `:path` option creates a temp file — always pass `path:` explicitly for predictable output locations.
- `save/2` vs `create/2`: use `save/2` for transforming existing files; `create/2` is for generating new images from ImageMagick drawing commands.
- `resize_to_fill` crops — if you need the full image preserved, use `resize_to_limit`.
- Mogrify raises on failure — always `rescue` in the calling code or wrap in a Task with error handling.
- ImageMagick has known CVEs related to processing untrusted files (ImageTragick). Apply OS-level ImageMagick policy.xml restrictions and validate file types before processing.
- Do not run `Mogrify` in the LiveView process — offload to an Oban worker.

---

## Storage Behaviour Pattern

**The pattern: define a behaviour, implement adapters, select via config.**

This follows the CLAUDE.md iron law: "WRAP THIRD-PARTY LIBRARY APIs behind project-owned modules."

### Behaviour Definition

```elixir
# lib/link_hub/media/storage.ex
defmodule LinkHub.Media.Storage do
  @moduledoc """
  Behaviour for file storage adapters.
  All storage operations go through this module — never call ExAws directly.
  """

  @type key :: String.t()
  @type bucket :: String.t()
  @type opts :: keyword()
  @type upload_result :: {:ok, key()} | {:error, term()}

  @doc "Generate a presigned URL for direct client upload"
  @callback presigned_upload_url(bucket, key, opts) ::
              {:ok, String.t()} | {:error, term()}

  @doc "Generate a presigned URL for client download"
  @callback presigned_download_url(bucket, key, opts) ::
              {:ok, String.t()} | {:error, term()}

  @doc "Upload a file from a local path (server-side)"
  @callback upload_file(bucket, key, local_path :: String.t(), opts) ::
              upload_result()

  @doc "Delete an object"
  @callback delete_object(bucket, key, opts) ::
              :ok | {:error, term()}

  @doc "Check if an object exists and return metadata"
  @callback head_object(bucket, key, opts) ::
              {:ok, map()} | {:error, :not_found} | {:error, term()}

  # Delegate to configured adapter
  def adapter, do: Application.get_env(:link_hub, :storage_adapter, __MODULE__.S3)

  defdelegate presigned_upload_url(bucket, key, opts \\ []), to: adapter()
  defdelegate presigned_download_url(bucket, key, opts \\ []), to: adapter()
  defdelegate upload_file(bucket, key, local_path, opts \\ []), to: adapter()
  defdelegate delete_object(bucket, key, opts \\ []), to: adapter()
  defdelegate head_object(bucket, key, opts \\ []), to: adapter()
end
```

### S3 Adapter

```elixir
# lib/link_hub/media/storage/s3.ex
defmodule LinkHub.Media.Storage.S3 do
  @behaviour LinkHub.Media.Storage

  @impl true
  def presigned_upload_url(bucket, key, opts) do
    expires_in = Keyword.get(opts, :expires_in, 900)
    content_type = Keyword.get(opts, :content_type)

    headers =
      if content_type, do: [{"content-type", content_type}], else: []

    ExAws.Config.new(:s3)
    |> ExAws.S3.presigned_url(:put, bucket, key,
      expires_in: expires_in,
      headers: headers
    )
  end

  @impl true
  def presigned_download_url(bucket, key, opts) do
    expires_in = Keyword.get(opts, :expires_in, 3600)

    ExAws.Config.new(:s3)
    |> ExAws.S3.presigned_url(:get, bucket, key, expires_in: expires_in)
  end

  @impl true
  def upload_file(bucket, key, local_path, opts) do
    content_type = Keyword.get(opts, :content_type, "application/octet-stream")

    local_path
    |> File.stream!([], 5 * 1024 * 1024)
    |> ExAws.S3.upload(bucket, key, content_type: content_type)
    |> ExAws.request()
    |> case do
      {:ok, _} -> {:ok, key}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def delete_object(bucket, key, _opts) do
    case ExAws.S3.delete_object(bucket, key) |> ExAws.request() do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def head_object(bucket, key, _opts) do
    case ExAws.S3.head_object(bucket, key) |> ExAws.request() do
      {:ok, %{headers: headers}} ->
        {:ok, headers_to_map(headers)}
      {:error, {:http_error, 404, _}} ->
        {:error, :not_found}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp headers_to_map(headers) do
    Enum.reduce(headers, %{}, fn {k, v}, acc ->
      Map.put(acc, String.downcase(k), v)
    end)
  end
end
```

### Local Adapter (dev/test)

```elixir
# lib/link_hub/media/storage/local.ex
defmodule LinkHub.Media.Storage.Local do
  @behaviour LinkHub.Media.Storage

  @base_url "http://localhost:4000"
  @upload_dir "priv/static/uploads"

  @impl true
  def presigned_upload_url(_bucket, key, _opts) do
    # Return a URL to the local upload endpoint
    {:ok, "#{@base_url}/dev/upload/#{key}"}
  end

  @impl true
  def presigned_download_url(_bucket, key, _opts) do
    {:ok, "#{@base_url}/uploads/#{key}"}
  end

  @impl true
  def upload_file(_bucket, key, local_path, _opts) do
    dest = Path.join([@upload_dir, key])
    dest |> Path.dirname() |> File.mkdir_p!()
    File.copy!(local_path, dest)
    {:ok, key}
  end

  @impl true
  def delete_object(_bucket, key, _opts) do
    case File.rm(Path.join(@upload_dir, key)) do
      :ok -> :ok
      {:error, :enoent} -> :ok  # idempotent
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def head_object(_bucket, key, _opts) do
    path = Path.join(@upload_dir, key)
    case File.stat(path) do
      {:ok, stat} -> {:ok, %{"content-length" => Integer.to_string(stat.size)}}
      {:error, :enoent} -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end
end
```

### Mock Adapter (test)

```elixir
# lib/link_hub/media/storage/mock.ex (only compiled in test)
defmodule LinkHub.Media.Storage.Mock do
  @behaviour LinkHub.Media.Storage

  @impl true
  def presigned_upload_url(_bucket, key, _opts),
    do: {:ok, "https://s3.example.com/#{key}?presigned=true"}

  @impl true
  def presigned_download_url(_bucket, key, _opts),
    do: {:ok, "https://s3.example.com/#{key}?download=true"}

  @impl true
  def upload_file(_bucket, key, _local_path, _opts), do: {:ok, key}

  @impl true
  def delete_object(_bucket, _key, _opts), do: :ok

  @impl true
  def head_object(_bucket, _key, _opts),
    do: {:ok, %{"content-length" => "1024"}}
end
```

### Config-Based Adapter Selection

```elixir
# config/dev.exs
config :link_hub, :storage_adapter, LinkHub.Media.Storage.Local

# config/test.exs
config :link_hub, :storage_adapter, LinkHub.Media.Storage.Mock

# config/runtime.exs (prod uses S3 by default — no config needed as S3 is the default)
# Or explicitly:
# config :link_hub, :storage_adapter, LinkHub.Media.Storage.S3
```

---

## Considered but Rejected

### arc / waffle

- **Why not**: Waffle (the arc successor) is a full file upload framework that handles storage, transformations, and URL generation in one library. It adds significant complexity and couples storage decisions to the resource model. For LinkHub's architecture with Ash resources, building a thin behaviour adapter over ex_aws_s3 gives more control and avoids the "magic" that makes debugging difficult.

### ex_aws with Req adapter

- **Why not**: ExAws has a hackney adapter built-in. A Req adapter for ExAws exists (`ex_aws_req`) but is community-maintained and less battle-tested. Since hackney is already a transitive dep of many Phoenix apps, adding it explicitly is not a burden.

### ImageMagick via System.cmd directly

- **Why not**: Mogrify handles temporary file management, argument quoting, and error parsing. Hand-rolling `System.cmd(["convert", ...])` requires reimplementing all of that.

### vix / evision (NIF-based image processing)

- **Why not**: vix (libvips bindings) is faster than mogrify for high-throughput image processing but requires compiling a NIF. For a messaging app with moderate upload volume, mogrify's simplicity and no-NIF approach is preferable. Revisit if image processing becomes a bottleneck.

---

## No Library Needed

- **File type detection**: Use `:file.read_file_info/1` for basic stat, and check magic bytes manually for MIME sniffing — or use the `mime` library (already a transitive dep of Phoenix) for extension-based lookup: `MIME.from_path("file.jpg")` returns `"image/jpeg"`.
- **UUID key generation**: `Ash.UUIDv7.generate()` (already in project) for unique storage keys.
- **File size validation**: Plain `File.stat!/1` returns `%File.Stat{size: integer()}` — no library needed.

---

## Compatibility Notes

- **Elixir version**: ex_aws ~> 2.5 requires Elixir 1.12+; project is on 1.17 — fully compatible
- **hackney version**: Use `~> 1.9` (the 1.x stable line). The 3.x line is a major rewrite with limited adoption.
- **sweet_xml version**: `~> 0.7` — last release 0.7.5, stable
- **mogrify version**: `~> 0.9` — requires ImageMagick 7.x on the system; ImageMagick 6.x works but some flags differ
- **Known conflicts**: None with current mix.exs. hackney does not conflict with Finch (both can coexist; they serve different callers).
- **ImageMagick system dep**: Must be present in Dockerfile and CI. Add `RUN apt-get install -y imagemagick` to Dockerfile and to `.github/workflows/ci.yml` setup steps.
- **Docker/CI note**: ImageMagick default policy.xml on Debian restricts PDF/PS processing by default — this is correct behavior for security. Only image formats need to be allowed.
