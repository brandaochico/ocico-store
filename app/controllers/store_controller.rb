# frozen_string_literal: true

class StoreController < Spree::BaseController
  include Spree::Core::ControllerHelpers::Pricing
  include Spree::Core::ControllerHelpers::Order
  include Taxonomies

  # Vary the cached response by the locale actually rendered. This runs at
  # response time, after set_user_language has resolved I18n.locale, so it must
  # read I18n.locale rather than config_locale — see the comment on that method.
  etag { I18n.locale }

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

  # Solidus's set_user_language consults this before falling back to
  # I18n.default_locale:
  #
  #   params[:locale] -> session[:locale] -> config_locale -> I18n.default_locale
  #
  # It has to answer "what locale is this store configured for", not "what
  # locale is set right now". Returning I18n.locale made it the latter, and
  # I18n.locale is thread-local and is not reset between requests — so a
  # visitor who had never chosen a language inherited whatever the previous
  # request on that Puma thread left behind, and set_user_language then wrote
  # that into their session, making it stick. A Brazilian store served English
  # to some visitors and Portuguese to others, by thread.
  def config_locale
    I18n.default_locale
  end

  def lock_order
    Spree::OrderMutex.with_lock!(@order) { yield }
  rescue Spree::OrderMutex::LockFailed
    flash[:error] = t("spree.order_mutex_error")
    redirect_to cart_path
  end
end
