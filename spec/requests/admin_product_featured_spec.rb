# frozen_string_literal: true

require 'solidus_starter_frontend_spec_helper'

# The "Destaque na home" checkbox, in both admins.
RSpec.describe "Marking a product for the home page", type: :request do
  let!(:store) { create(:store) }
  let(:product) { create(:product) }

  before { sign_in(create(:admin_user)) }

  context "in the classic admin" do
    it "shows the checkbox on the product form" do
      get spree.edit_admin_product_path(product), params: { solidus_admin: false }

      expect(response.body).to include("Featured on the home page", 'name="product[featured]"') # both admins still run in English
      expect(response.body).not_to include("translation missing")
    end

    it "saves it" do
      patch spree.admin_product_path(product), params: { product: { featured: "1" } }

      expect(product.reload).to be_featured
    end
  end

  context "in solidus_admin" do
    it "shows the checkbox in the Publishing panel" do
      get solidus_admin.edit_product_path(product)

      expect(response.body).to include("Featured on the home page", 'name="product[featured]"') # both admins still run in English
      expect(response.body).not_to include("translation missing")
    end

    it "saves it, and unchecking sticks" do
      patch solidus_admin.product_path(product), params: { product: { featured: "1" } }
      expect(product.reload).to be_featured

      patch solidus_admin.product_path(product), params: { product: { featured: "0" } }
      expect(product.reload).not_to be_featured
    end
  end
end
