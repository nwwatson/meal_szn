import { Controller } from "@hotwired/stimulus"

// Watches for Turbo Stream broadcasts on the ai_task_status partial.
// When the status changes to completed/failed, redirects the user.
// Falls back to polling if the WebSocket connection is not established.
export default class extends Controller {
  static targets = ["statusFrame"]
  static values = {
    pollUrl: String,
    completedUrl: String,
    failedUrl: String,
    pollInterval: { type: Number, default: 2000 }
  }

  connect() {
    this.pollTimer = null
    this.websocketConnected = false

    // Check if Turbo cable subscription is active
    this.checkWebSocket()
  }

  disconnect() {
    this.stopPolling()
  }

  // Called when the turbo frame inside is replaced by a broadcast
  statusFrameTargetConnected(element) {
    const status = element.dataset.status
    const error = element.dataset.error

    if (status === "completed") {
      window.location.href = this.completedUrlValue
    } else if (status === "failed") {
      const failedUrl = new URL(this.failedUrlValue, window.location.origin)
      if (error) {
        failedUrl.searchParams.set("alert", `Operation failed: ${error}`)
      }
      window.location.href = failedUrl.toString()
    }
  }

  checkWebSocket() {
    // Give ActionCable a moment to connect, then start polling as fallback
    setTimeout(() => {
      if (!this.websocketConnected) {
        this.startPolling()
      }
    }, 3000)

    // Listen for ActionCable connection events
    if (window.Turbo && window.Turbo.connectStreamSource) {
      this.websocketConnected = true
    }

    // Also detect via cable consumer
    const cable = document.querySelector("[data-turbo-stream-source]")
    if (cable) {
      this.websocketConnected = true
    }
  }

  startPolling() {
    if (this.pollTimer) return
    if (!this.hasPollUrlValue) return

    this.pollTimer = setInterval(() => {
      this.poll()
    }, this.pollIntervalValue)
  }

  stopPolling() {
    if (this.pollTimer) {
      clearInterval(this.pollTimer)
      this.pollTimer = null
    }
  }

  async poll() {
    try {
      const response = await fetch(this.pollUrlValue, {
        headers: { "Accept": "text/html" }
      })

      if (response.redirected) {
        window.location.href = response.url
        this.stopPolling()
        return
      }

      if (response.ok) {
        const html = await response.text()
        const parser = new DOMParser()
        const doc = parser.parseFromString(html, "text/html")
        const frame = doc.querySelector("turbo-frame")

        if (frame) {
          const status = frame.querySelector("[data-status]")?.dataset?.status
          if (status === "completed") {
            window.location.href = this.completedUrlValue
            this.stopPolling()
          } else if (status === "failed") {
            window.location.href = this.failedUrlValue
            this.stopPolling()
          }
        }
      }
    } catch {
      // Network error — keep polling
    }
  }
}
