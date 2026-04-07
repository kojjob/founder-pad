# LiveView External Uploads Research

## Sources (4 fetched, 2 T1, 2 T2)

### Phoenix LiveView External Uploads (Official HexDocs)
**URL**: https://hexdocs.pm/phoenix_live_view/external-uploads.html **[T1]**

**Key Points:**
- Presigner function is 2-arity: `fn entry, socket -> {:ok, meta, socket} | {:error, meta, socket} end`
- **`meta` map must contain `:uploader` key** — the JavaScript function name (e.g., `"S3"`, `"UpChunk"`)
- Entry object provides three callback methods:
  - `entry.progress(percent)` — report progress 0–100
  - `entry.error(reason)` — signal failure
  - `entry.done(result)` — mark complete with metadata
- LiveSocket initialized with `uploaders: Uploaders` object containing uploader functions
- `onViewError` callback allows canceling ongoing uploads if LiveView disconnects

---

### Direct File Uploads to Amazon S3 with Phoenix LiveView (AppSignal Blog)
**URL**: https://blog.appsignal.com/2024/03/19/direct-file-uploads-to-amazon-s3-with-phoenix-liveview.html **[T2]**

**Key Points:**
- Backend generates **presigned URLs** using a library like `SimpleS3Upload` — temporary authenticated URLs that clients POST to without exposing AWS credentials
- `allow_upload(:file, external: &presign_entry/2, ...)` wires the presigner
- Presigner returns metadata with `uploader: "S3"`, `key`, `url`, and `fields` (presigned form fields)
- Frontend uses `consume_uploaded_entries()` to retrieve final S3 object URLs after client-side upload completes
- UI patterns: `phx-drop-target` for drag-and-drop, `live_file_input` component, `upload_errors/2` for validation errors, `live_img_preview` for real-time preview

---

### Phoenix LiveView GitHub External Uploads Guide (v0.20.17)
**URL**: https://github.com/phoenixframework/phoenix_live_view/blob/v0.20.17/guides/client/uploads-external.md **[T1]**

**Key Points:**
- Presigner receives `entry` (with `client_name`, `client_type`, `client_size`) and `socket`
- Two main patterns: **chunked uploads** (UpChunk for resumable, large files) and **S3 direct POST** (simpler, max 5GB)
- JavaScript uploader signature: `Uploaders.S3 = function(entries, onViewError) { ... }`
- `onViewError` passed as callback for cancellation on disconnect
- `upload_errors/2` on server retrieves validation/failure reasons before processing

---

### S3 Direct Upload Implementation (DEV Community)
**URL**: https://dev.to/azyzz/file-upload-to-aws-s3-or-s3-compatible-bucket-digitalocean-spaces-from-phoenix-liveview-using-elixir-3eof **[T3]**

**Key Points:**
- JavaScript FormData construction: append presigned `fields`, then append `file`
- XMLHttpRequest with progress tracking via `xhr.upload.addEventListener("progress")`
- HTTP 204 response triggers `entry.progress(100)` (S3's success response)
- Server module (e.g., `S3Uploader.meta()`) abstracts AWS signing complexity

---

## Code Examples

### Server-Side Presigner (Elixir)
```elixir
# lib/your_app_web/live/upload_live.ex
def handle_event("validate", _params, socket) do
  {:noreply, socket}
end

defp presign_upload(entry, socket) do
  # Use ExAws or similar to generate presigned form POST metadata
  {:ok, %{
    uploader: "S3",
    key: "uploads/#{uuid()}/#{entry.client_name}",
    url: "https://#{bucket}.s3.amazonaws.com",
    fields: %{
      "Content-Type" => entry.client_type,
      "policy" => policy_base64,
      "signature" => signature,
      # ... other AWS presigned fields
    }
  }, socket}
end
```

### JavaScript S3 Uploader
```javascript
// assets/js/uploaders.js
let Uploaders = {}

Uploaders.S3 = function(entries, onViewError) {
  entries.forEach(entry => {
    let formData = new FormData()
    let {url, fields} = entry.meta

    // Append presigned form fields
    Object.entries(fields).forEach(([key, val]) => {
      formData.append(key, val)
    })

    // Append file last (S3 requirement)
    formData.append("file", entry.file)

    let xhr = new XMLHttpRequest()

    // Cancel if LiveView disconnects
    onViewError(() => xhr.abort())

    // Handle response
    xhr.onload = () => {
      if (xhr.status === 204) {
        entry.progress(100) // S3 returns 204 on success
      } else {
        entry.error("Upload failed")
      }
    }

    xhr.onerror = () => entry.error("Network error")

    // Track progress
    xhr.upload.addEventListener("progress", (event) => {
      if (event.lengthComputable) {
        let percent = Math.round((event.loaded / event.total) * 100)
        if (percent < 100) entry.progress(percent)
      }
    })

    xhr.open("POST", url, true)
    xhr.send(formData)
  })
}

export default Uploaders
```

### LiveView Configuration & UI
```elixir
# In your LiveView mount
def mount(_params, _session, socket) do
  {:ok,
    socket
    |> allow_upload(:file,
      accept: ~w(.png .jpg .jpeg .webp),
      max_entries: 1,
      max_file_size: 10_000_000,
      external: &presign_upload/2
    )
  }
end

def render(assigns) do
  ~H"""
  <form phx-submit="save" phx-drop-target={@uploads.file.ref}>
    <.live_file_input upload={@uploads.file} />

    <!-- Show upload errors -->
    <%= for err <- upload_errors(@uploads.file) do %>
      <p class="text-red-600"><%= err %></p>
    <% end %>

    <!-- Progress bars -->
    <%= for entry <- @uploads.file.entries do %>
      <div>
        <p><%= entry.client_name %></p>
        <progress value={entry.progress} max="100" />
        <span><%= entry.progress %>%</span>
      </div>
    <% end %>

    <button type="submit">Save</button>
  </form>
  """
end

def handle_event("save", _params, socket) do
  # Consume entries after client-side upload completes
  uploaded_files =
    consume_uploaded_entries(socket, :file, fn _meta, entry ->
      {:ok, entry}
    end)

  {:noreply, socket}
end
```

### LiveSocket Initialization
```javascript
// assets/js/app.js
import Uploaders from "./uploaders"

let liveSocket = new LiveSocket("/live", Socket, {
  uploaders: Uploaders,  // Register all uploader functions
  params: {_csrf_token: csrfToken}
})

liveSocket.connect()
```

---

## Key Gotchas

1. **`meta` must have `:uploader` key** — without it, LiveView won't find the JavaScript handler
2. **File must be appended last in S3 FormData** — S3's multipart form POST requires file at the end
3. **HTTP 204 is S3's success response** — not 200; check for exactly 204 in `xhr.onload`
4. **Progress < 100 before completion** — `entry.progress(100)` signals done; avoid calling it too early
5. **`onViewError` callback is critical** — cancels xhr if LiveView disconnects, preventing orphaned requests
6. **`consume_uploaded_entries()` after client upload** — don't call it until `entry.progress(100)` or client-side completion signal
7. **UpChunk vs. S3 direct POST** — use UpChunk only if you need resumable uploads; S3 direct POST is simpler and faster for most cases
