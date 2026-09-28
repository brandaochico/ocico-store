import { Controller } from "@hotwired/stimulus"

// Header dropdown with two ways in:
//
//   hover  — opens while the pointer is over it, closes when it leaves
//   click  — pins it open, and it stays open until a click lands outside
//
// The pinned flag is what keeps the two from fighting: once pinned, leaving
// with the pointer must not close the menu, which is the whole point of
// clicking it.
export default class extends Controller {
  static targets = ["menu", "button"]

  connect() {
    this.pinned = false
  }

  show() {
    this.open()
  }

  hide() {
    if (this.pinned) return

    this.close()
  }

  toggle(event) {
    // The button is a link for no-JS users; with JS it drives the menu.
    event.preventDefault()
    // Otherwise the window listener sees this same click and unpins straight away.
    event.stopPropagation()

    this.pinned = !this.pinned
    this.pinned ? this.open() : this.close()
  }

  closeOnOutsideClick(event) {
    if (this.element.contains(event.target)) return

    this.unpinAndClose()
  }

  unpinAndClose() {
    this.pinned = false
    this.close()
  }

  open() {
    this.menuTarget.classList.remove("hidden")
    this.buttonTarget.setAttribute("aria-expanded", "true")
  }

  close() {
    this.menuTarget.classList.add("hidden")
    this.buttonTarget.setAttribute("aria-expanded", "false")
  }
}
