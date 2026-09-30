import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["drawer"];

  toggle() {
    this.drawerTarget.classList.toggle("-translate-x-full");
    document.getElementById("overlay").classList.toggle("hidden");
    // Locks the page behind the drawer so it doesn't scroll underneath the
    // (visually fixed) overlay while the drawer is open. Toggled in lockstep
    // with the two classes above rather than tracked as separate open/closed
    // state, so it can only ever be out of sync with them if a caller adds
    // one of these classes directly instead of going through toggle().
    document.body.classList.toggle("overflow-hidden");
  }
}
