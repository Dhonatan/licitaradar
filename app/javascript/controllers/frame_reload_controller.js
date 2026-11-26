import { Controller } from "@hotwired/stimulus"

// Points the surrounding Turbo Frame at `url` after `delay` milliseconds, so a frame
// showing a loading state asks the server again (e.g. while a background job fetches
// the tender's documents). The server decides when to stop by not rendering this.
export default class extends Controller {
  static values = { url: String, delay: { type: Number, default: 3000 } }

  connect() {
    this.timeout = setTimeout(() => {
      const frame = this.element.closest("turbo-frame")
      if (frame) frame.src = this.urlValue
    }, this.delayValue)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }
}
