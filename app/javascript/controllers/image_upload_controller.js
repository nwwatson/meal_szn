import { Controller } from "@hotwired/stimulus"

// Drag-and-drop image upload with live preview
// Supports single (cover) and multiple (additional) image uploads
export default class extends Controller {
  static targets = ["input", "dropZone", "preview", "placeholder"]
  static values = {
    multiple: { type: Boolean, default: false },
    maxSize: { type: Number, default: 10485760 }, // 10MB
    accept: { type: String, default: "image/jpeg,image/png,image/webp,image/gif" }
  }

  connect() {
    this.dragCounter = 0
  }

  // Drag events
  dragenter(event) {
    event.preventDefault()
    this.dragCounter++
    this.dropZoneTarget.classList.add("border-primary-400", "bg-primary-50/50")
    this.dropZoneTarget.classList.remove("border-warm-300")
  }

  dragleave(event) {
    event.preventDefault()
    this.dragCounter--
    if (this.dragCounter === 0) {
      this.dropZoneTarget.classList.remove("border-primary-400", "bg-primary-50/50")
      this.dropZoneTarget.classList.add("border-warm-300")
    }
  }

  dragover(event) {
    event.preventDefault()
  }

  drop(event) {
    event.preventDefault()
    this.dragCounter = 0
    this.dropZoneTarget.classList.remove("border-primary-400", "bg-primary-50/50")
    this.dropZoneTarget.classList.add("border-warm-300")

    const files = event.dataTransfer.files
    if (files.length > 0) {
      this.handleFiles(files)
    }
  }

  // Click to browse
  browse() {
    this.inputTarget.click()
  }

  // File input changed
  changed() {
    const files = this.inputTarget.files
    if (files.length > 0) {
      this.handleFiles(files)
    }
  }

  handleFiles(files) {
    const validFiles = Array.from(files).filter(file => this.validateFile(file))

    if (!this.multipleValue) {
      // Single file mode — show one preview, replace existing
      if (validFiles.length > 0) {
        this.showSinglePreview(validFiles[0])
      }
    } else {
      // Multiple file mode — append previews
      validFiles.forEach(file => this.appendPreview(file))
    }
  }

  validateFile(file) {
    const allowedTypes = this.acceptValue.split(",").map(t => t.trim())

    if (!allowedTypes.includes(file.type)) {
      this.showError(`"${file.name}" is not a supported image type. Use JPEG, PNG, WebP, or GIF.`)
      return false
    }

    if (file.size > this.maxSizeValue) {
      const maxMB = Math.round(this.maxSizeValue / 1048576)
      this.showError(`"${file.name}" exceeds the ${maxMB}MB size limit.`)
      return false
    }

    return true
  }

  showSinglePreview(file) {
    const reader = new FileReader()
    reader.onload = (e) => {
      this.previewTarget.innerHTML = `
        <div class="relative inline-block group">
          <img src="${e.target.result}" class="rounded-xl shadow-sm max-h-48 object-cover" alt="Preview">
          <button type="button" data-action="image-upload#clearSingle"
            class="absolute -top-2 -right-2 w-6 h-6 bg-red-500 text-white rounded-full flex items-center justify-center
                   opacity-0 group-hover:opacity-100 transition-opacity shadow-sm hover:bg-red-600">
            <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
            </svg>
          </button>
          <p class="text-xs text-warm-500 mt-1.5">${file.name} (${this.formatSize(file.size)})</p>
        </div>
      `
      this.previewTarget.classList.remove("hidden")
      if (this.hasPlaceholderTarget) {
        this.placeholderTarget.classList.add("hidden")
      }
    }
    reader.readAsDataURL(file)
  }

  appendPreview(file) {
    const reader = new FileReader()
    reader.onload = (e) => {
      const wrapper = document.createElement("div")
      wrapper.className = "relative inline-block group"
      wrapper.innerHTML = `
        <img src="${e.target.result}" class="w-20 h-20 rounded-lg object-cover shadow-sm" alt="Preview">
        <button type="button" data-action="image-upload#removePreview"
          class="absolute -top-1.5 -right-1.5 w-5 h-5 bg-red-500 text-white rounded-full flex items-center justify-center
                 opacity-0 group-hover:opacity-100 transition-opacity shadow-sm hover:bg-red-600">
          <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
          </svg>
        </button>
        <p class="text-[10px] text-warm-500 mt-0.5 truncate max-w-[5rem]">${file.name}</p>
      `
      this.previewTarget.appendChild(wrapper)
      this.previewTarget.classList.remove("hidden")
    }
    reader.readAsDataURL(file)
  }

  clearSingle() {
    this.inputTarget.value = ""
    this.previewTarget.innerHTML = ""
    this.previewTarget.classList.add("hidden")
    if (this.hasPlaceholderTarget) {
      this.placeholderTarget.classList.remove("hidden")
    }
  }

  removePreview(event) {
    const wrapper = event.currentTarget.closest(".group")
    if (wrapper) {
      wrapper.remove()
    }
    // Note: removing the preview doesn't remove the file from the input.
    // For multi-file, the form will submit all selected files.
    // Removal of individual files from a FileList isn't supported natively.
  }

  showError(message) {
    // Brief inline error that auto-dismisses
    const el = document.createElement("div")
    el.className = "text-sm text-red-600 mt-1 animate-pulse"
    el.textContent = message
    this.dropZoneTarget.after(el)
    setTimeout(() => el.remove(), 4000)
  }

  formatSize(bytes) {
    if (bytes < 1024) return `${bytes} B`
    if (bytes < 1048576) return `${(bytes / 1024).toFixed(1)} KB`
    return `${(bytes / 1048576).toFixed(1)} MB`
  }
}
