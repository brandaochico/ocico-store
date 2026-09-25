# frozen_string_literal: true

class StoreController < Spree::BaseController
  include Spree::Core::ControllerHelpers::Pricing
  include Spree::Core::ControllerHelpers::Order
  include Taxonomies

  etag { config_locale }

  layout "storefront"

  def unauthorized
    render "shared/auth/unauthorized", layout: Spree::Config[:layout], status: 401
  end

  # Fetched by top_bar_controller.js on every page load and injected into the
  # header as raw HTML.
  #
  # The freshness check has to come *before* the render, not after it: when the
  # browser revalidates with a matching If-None-Match, fresh_when answers with
  # `head :not_modified`, and if a render already happened that's a second
  # render — AbstractController::DoubleRenderError, a 500. The first request of
  # a session sends no If-None-Match and so looks fine; every navigation after
  # that one blows up.
  def cart_link
    return unless stale?(etag: current_order, template: "shared/cart/_link_to_cart")

    render partial: "shared/cart/link_to_cart"
  end

  private

  def config_locale
    I18n.locale
  end

  def lock_order
    Spree::OrderMutex.with_lock!(@order) { yield }
  rescue Spree::OrderMutex::LockFailed
    flash[:error] = t("spree.order_mutex_error")
    redirect_to cart_path
  end
end
