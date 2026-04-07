let Uploaders = {}

Uploaders.S3 = function(entries, onViewError) {
  entries.forEach(entry => {
    let { url, fields } = entry.meta

    let xhr = new XMLHttpRequest()

    // Cancel upload if LiveView disconnects
    onViewError(() => xhr.abort())

    // Track upload progress
    xhr.upload.addEventListener("progress", (event) => {
      if (event.lengthComputable) {
        let percent = Math.round((event.loaded / event.total) * 100)
        if (percent < 100) {
          entry.progress(percent)
        }
      }
    })

    // Handle completion
    xhr.onload = () => {
      if (xhr.status === 200 || xhr.status === 204) {
        entry.progress(100)
      } else {
        entry.error("Upload failed with status " + xhr.status)
      }
    }

    xhr.onerror = () => entry.error("Network error during upload")

    // For S3 presigned PUT uploads
    xhr.open("PUT", url, true)

    // Set content type header if provided
    if (fields && fields["content-type"]) {
      xhr.setRequestHeader("Content-Type", fields["content-type"])
    }

    xhr.send(entry.file)
  })
}

export default Uploaders
