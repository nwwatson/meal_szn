import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  async toggle(event) {
    const form = event.target.closest("form")
    if (!form) return

    try {
      const csrfToken = document.querySelector("meta[name='csrf-token']")?.content
      await fetch(form.action, {
        method: "PATCH",
        headers: {
          "X-CSRF-Token": csrfToken,
          "Accept": "text/html"
        }
      })
      window.location.reload()
    } catch (e) {
      form.submit()
    }
  }
}
