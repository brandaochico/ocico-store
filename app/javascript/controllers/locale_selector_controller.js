import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ['selector', 'panel', 'button']

  submitForm() {
    this.selectorTarget.form.submit()
  }

  toggle(event) {
    // Without this the window listener below sees the same click and closes
    // the panel again in the same tick.
    event.stopPropagation()
    this.isOpen ? this.close() : this.open()
  }

  open() {
    this.panelTarget.classList.remove('hidden')
    this.buttonTarget.setAttribute('aria-expanded', 'true')
    this.selectorTarget.focus()
  }

  close() {
    if (!this.isOpen) return

    this.panelTarget.classList.add('hidden')
    this.buttonTarget.setAttribute('aria-expanded', 'false')
  }

  closeOnOutsideClick(event) {
    if (this.element.contains(event.target)) return

    this.close()
  }

  get isOpen() {
    return !this.panelTarget.classList.contains('hidden')
  }
}
