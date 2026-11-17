# frozen_string_literal: true

module CheckoutHelper
  def partial_name_with_fallback(prefix, partial_name, fallback_name = "default")
    if lookup_context.find_all("#{prefix}/_#{partial_name}").any?
      "#{prefix}/#{partial_name}"
    else
      "#{prefix}/#{fallback_name}"
    end
  end

  # "Entrega em 3 a 5 dias úteis", or "em até 4 dias úteis" when the carrier
  # gives a single number.
  def delivery_days_text(min_days, max_days)
    if max_days && max_days > min_days
      t("checkout.delivery.delivery_days_range", min: min_days, max: max_days)
    else
      t("checkout.delivery.delivery_days", count: max_days || min_days)
    end
  end
end
