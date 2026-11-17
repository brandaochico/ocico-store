# frozen_string_literal: true

# Records each shipping rate's delivery time, so checkout can show "3 a 5 dias
# úteis" next to the price.
#
# Spree::Stock::Estimator only asks a calculator for a cost; a rate has no
# place for a delivery time. spree_shipping_rates gained min/max_delivery_days,
# and this fills them for calculators that know one (today only
# MelhorEnvio::ShippingCalculator#delivery_days). Others leave them nil and
# the view shows no delivery time.
module ShippingRateDeliveryDays
  private

  def calculate_shipping_rates(package)
    super.each do |rate|
      calculator = rate.shipping_method.calculator
      next unless calculator.respond_to?(:delivery_days)

      rate.min_delivery_days, rate.max_delivery_days = calculator.delivery_days(package)
    end
  end

  ::Spree::Stock::Estimator.prepend self
end
