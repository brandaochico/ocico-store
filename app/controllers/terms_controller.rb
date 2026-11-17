# frozen_string_literal: true

# The store's terms of service, linked from the footer and shown again (in a
# scrolling box) at checkout's confirm step, where the customer accepts them.
# The text itself is a localized partial: terms/_content.<locale>.html.erb.
class TermsController < StoreController
  respond_to :html

  def show
  end

  private

  def accurate_title
    t("storefront.terms.title")
  end
end
