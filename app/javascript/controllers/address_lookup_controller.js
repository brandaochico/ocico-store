import { Controller } from "@hotwired/stimulus"

// Brazilian address helpers for the checkout address form: CEP mask, CEP
// lookup (ViaCEP) filling street/neighbourhood/city/state, and street number
// + neighbourhood required only when the country is Brazil.
export default class extends Controller {
  static targets = [ "country", "zipcode", "street", "number", "neighborhood", "city", "state", "message" ]
  static values = { brazilId: Number, states: Object, notFound: String }

  connect() {
    this.countryChanged()
  }

  countryChanged() {
    const brazilian = this.isBrazil()
    this.numberTarget.required = brazilian
    this.neighborhoodTarget.required = brazilian
    this.zipcodeTarget.maxLength = brazilian ? 9 : 524288
    if (!brazilian) this.hideMessage()
  }

  zipcodeChanged() {
    if (!this.isBrazil()) return

    const digits = this.zipcodeTarget.value.replace(/\D/g, "").slice(0, 8)
    this.zipcodeTarget.value = digits.length > 5 ? `${digits.slice(0, 5)}-${digits.slice(5)}` : digits

    if (digits.length === 8 && digits !== this.lastLookup) {
      this.lastLookup = digits
      this.lookup(digits)
    } else if (digits.length < 8) {
      this.lastLookup = null
      this.hideMessage()
    }
  }

  async lookup(cep) {
    this.abortController?.abort()
    this.abortController = new AbortController()
    const timeout = setTimeout(() => this.abortController.abort(), 5000)

    try {
      const response = await fetch(`https://viacep.com.br/ws/${cep}/json/`, { signal: this.abortController.signal })
      const data = await response.json()
      if (cep !== this.lastLookup) return

      if (data.erro) {
        this.showMessage(this.notFoundValue)
        return
      }

      this.hideMessage()
      // Single-CEP towns come back without street or neighbourhood: only
      // overwrite what ViaCEP actually knows.
      this.fill(this.streetTarget, data.logradouro)
      this.fill(this.neighborhoodTarget, data.bairro)
      this.fill(this.cityTarget, data.localidade)
      this.selectState(data.uf)

      const next = this.streetTarget.value ? this.numberTarget : this.streetTarget
      next.focus()
    } catch {
      // Offline, slow or blocked: the customer just types the address in.
    } finally {
      clearTimeout(timeout)
    }
  }

  fill(input, value) {
    if (value) input.value = value
  }

  selectState(abbr) {
    const id = this.statesValue[abbr]
    if (!id || !this.hasStateTarget) return

    this.stateTarget.value = String(id)
  }

  isBrazil() {
    return this.hasBrazilIdValue && Number(this.countryTarget.value) === this.brazilIdValue
  }

  showMessage(text) {
    this.messageTarget.textContent = text
    this.messageTarget.classList.remove("hidden")
  }

  hideMessage() {
    this.messageTarget.textContent = ""
    this.messageTarget.classList.add("hidden")
  }
}
