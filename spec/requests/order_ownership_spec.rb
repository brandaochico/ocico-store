# frozen_string_literal: true

require "solidus_starter_frontend_spec_helper"

# An order that belongs to an account is visible to that account and to
# admins only — never through its guest token (app/models/order_ownership_ability.rb).
RSpec.describe "Who can see an order page", type: :request do
  let!(:store) { create(:store) }
  let(:owner) { create(:user) }
  let(:order) { create(:completed_order_with_totals, user: owner, store:) }

  def expect_order_hidden
    expect(response).not_to have_http_status(:ok)
    expect(response.body).not_to include(order.number)
  end

  it "shows the order to its owner" do
    sign_in(owner)

    get order_path(order)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(order.number)
  end

  it "hides it from another customer" do
    sign_in(create(:user))

    get order_path(order)

    expect_order_hidden
  end

  it "hides it from another customer who has the order's token link" do
    sign_in(create(:user))

    get token_order_path(order, order.guest_token)

    expect_order_hidden
  end

  it "hides it from a visitor who has the order's token link" do
    get token_order_path(order, order.guest_token)

    expect_order_hidden
  end

  it "shows any order to an admin" do
    sign_in(create(:admin_user))

    get order_path(order)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(order.number)
  end

  context "with a guest order (no account)" do
    let(:order) { create(:completed_order_with_totals, user: nil, email: "visitante@example.com", store:) }

    it "still opens with its token link, which is how a guest reaches it" do
      get token_order_path(order, order.guest_token)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(order.number)
    end

    it "stays hidden without the token" do
      sign_in(create(:user))

      get order_path(order)

      expect_order_hidden
    end
  end
end
