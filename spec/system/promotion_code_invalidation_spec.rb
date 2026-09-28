# frozen_string_literal: true

require 'solidus_starter_frontend_spec_helper'

RSpec.describe 'Promotion Code Invalidation', type: :system, js: true do
  let!(:promotion) do
    FactoryBot.create(
      :promotion_with_item_adjustment,
      code: "PROMO",
      per_code_usage_limit: 1,
      adjustment_rate: 5
    )
  end

  before do
    create(:store)
    FactoryBot.create(:product_in_stock, name: "DL-44")
    FactoryBot.create(:product_in_stock, name: "E-11")

    visit products_path
    click_link "DL-44"
    click_button I18n.t("spree.add_to_cart")

    visit products_path
    click_link "E-11"
    click_button I18n.t("spree.add_to_cart")
  end

  it 'adding the promotion to a cart with two applicable items' do
    fill_in I18n.t("spree.coupon_code"), with: "PROMO"
    click_button I18n.t("spree.apply_code")

    expect(page).to have_content("The coupon code was successfully applied to your order")

    within("#cart_adjustments") do
      expect(page).to have_content(Spree::Money.new(-10).to_s)
    end

    # Remove an item

    fill_in "order_line_items_attributes_0_quantity", with: 0
    click_button I18n.t("spree.update")
    within("#cart_adjustments") do
      expect(page).to have_content(Spree::Money.new(-5).to_s)
    end

    # Add it back
    visit products_path
    click_link "DL-44"
    click_button I18n.t("spree.add_to_cart")
    within("#cart_adjustments") do
      expect(page).to have_content(Spree::Money.new(-10).to_s)
    end
  end
end
