import { Controller } from "@hotwired/stimulus"

// Delivery step: when the customer picks another shipping rate, show its
// freight and the resulting total in the order summary straight away. Both
// amounts come pre-formatted from the server (one pair per rate).
export default class extends Controller {
  static targets = [ "shipping", "total" ]

  select({ params: { shipping, total } }) {
    if (this.hasShippingTarget) this.shippingTarget.textContent = shipping
    if (this.hasTotalTarget) this.totalTarget.textContent = total
  }
}
