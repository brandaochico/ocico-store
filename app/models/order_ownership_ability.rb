# frozen_string_literal: true

# An order that belongs to an account is visible only to that account (and to
# admins). Registered on Spree::Ability in config/initializers/spree.rb.
#
# Solidus's DefaultCustomer permission set lets anyone holding the order's
# guest token see or update it — `order.user == user || token == guest_token`
# — even when the order has an owner. The token travels in URLs
# (/orders/:number/token/:token) and cookies, so a forwarded or leaked link
# would expose another customer's order: address, items, payment. Here the
# token keeps working only for guest orders (no user), which is what it exists
# for: a visitor who checked out without an account.
#
# Extension abilities are merged after the role permission sets, so this
# `cannot` would also override an admin's `can :manage, :all` — hence admins
# are left out explicitly.
class OrderOwnershipAbility
  include CanCan::Ability

  def initialize(user)
    return if user&.has_spree_role?(:admin)

    cannot [ :show, :update ], Spree::Order do |order, _token|
      order.user_id.present? && order.user_id != user&.id
    end
  end
end
