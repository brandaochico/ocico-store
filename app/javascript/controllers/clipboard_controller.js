import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "source", "button" ]
  static values = { copiedLabel: String }

  async copy() {
    const text = this.sourceTarget.value
    try {
      await navigator.clipboard.writeText(text)
    } catch {
      // Clipboard API needs a secure context; select the text so the customer
      // can still copy it by hand.
      this.sourceTarget.select()
      return
    }

    const label = this.buttonTarget.textContent
    this.buttonTarget.textContent = this.copiedLabelValue
    setTimeout(() => { this.buttonTarget.textContent = label }, 2000)
  }
}
