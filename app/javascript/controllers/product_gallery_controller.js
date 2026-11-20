import { Controller } from "@hotwired/stimulus"

// Product page gallery (app/views/products/_product_gallery.html.erb):
// clicking a thumbnail shows that image, and hovering the image magnifies it
// under the cursor. Replaces the starter theme's product.js thumbnail code,
// which bound on DOMContentLoaded and so stopped working after any Turbo
// navigation.
export default class extends Controller {
  static targets = ["main", "thumbnail", "stage", "lens"]

  select(event) {
    const button = event.currentTarget
    this.mainTarget.src = button.dataset.url
    this.mainTarget.alt = button.dataset.alt || ""
    this.mainTarget.dataset.zoomUrl = button.dataset.zoomUrl

    this.thumbnailTargets.forEach((thumbnail) => {
      const selected = thumbnail === button
      thumbnail.setAttribute("aria-current", selected)
      thumbnail.classList.toggle("border-primary", selected)
      thumbnail.classList.toggle("border-transparent", !selected)
    })
  }

  // Only for a real mouse: on touch screens "hover" is a tap, and a magnifier
  // stuck on after it would just hide the photo.
  zoomIn(event) {
    if (!this.hasLensTarget || !this.hasMainTarget || !this.canHover) return

    this.lensTarget.style.backgroundImage = `url("${this.mainTarget.dataset.zoomUrl}")`
    this.lensTarget.classList.remove("hidden")
    this.zoomMove(event)
  }

  zoomMove(event) {
    if (!this.hasLensTarget || this.lensTarget.classList.contains("hidden")) return

    const box = this.stageTarget.getBoundingClientRect()
    const x = this.#percent((event.clientX - box.left) / box.width)
    const y = this.#percent((event.clientY - box.top) / box.height)
    this.lensTarget.style.backgroundPosition = `${x}% ${y}%`
  }

  zoomOut() {
    if (this.hasLensTarget) this.lensTarget.classList.add("hidden")
  }

  get canHover() {
    return window.matchMedia("(hover: hover) and (pointer: fine)").matches
  }

  #percent(fraction) {
    return Math.min(100, Math.max(0, fraction * 100))
  }
}
