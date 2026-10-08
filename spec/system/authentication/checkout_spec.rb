# frozen_string_literal: true

require 'solidus_starter_frontend_spec_helper'

RSpec.feature 'Checkout', :js, type: :system do
  include SolidusStarterFrontend::System::CheckoutHelpers

  given!(:store) { create(:store) }
  given!(:country) { create(:country, name: 'United States', states_required: true) }
  given!(:state) { create(:state, name: 'Alabama', country: country) }
  given!(:shipping_method) do
    shipping_method = create(:shipping_method)
    calculator = Spree::Calculator::Shipping::PerItem.create!(calculable: shipping_method, preferred_amount: 10)
    shipping_method.calculator = calculator
    shipping_method.tap(&:save)
  end

  given!(:zone)    { create(:zone) }
  given!(:address) { create(:address) }
  given!(:payment_method) { create :check_payment_method }

  background do
    @product = create(:product, name: 'Solidus hoodie')
    @product.master.stock_items.first.set_count_on_hand(1)

    # Bypass gateway error on checkout | ..or stub a gateway
    stub_spree_preferences(allow_checkout_on_gateway_error: true)

    visit products_path
  end

  # Regression test for https://github.com/solidusio/solidus/issues/1588
  scenario 'leaving and returning to address step' do
    stub_spree_preferences(Spree::Auth::Config, registration_step: true)
    click_link 'Solidus hoodie'
    click_button I18n.t("spree.add_to_cart")
    within('h1') { expect(page).to have_text I18n.t('spree.shopping_cart') }
    click_button I18n.t("spree.checkout")

    within '#guest_checkout' do
      fill_in I18n.t("spree.email"), with: 'test@example.com'
    end
    click_on I18n.t("spree.continue")

    click_on I18n.t("spree.cart")

    click_on I18n.t("spree.checkout")

    expect(page).to have_content I18n.t("spree.billing_address")
  end

  context 'without payment being required' do
    scenario 'allow a visitor to checkout as guest, without registration' do
      click_link 'Solidus hoodie'
      click_button I18n.t("spree.add_to_cart")
      within('h1') { expect(page).to have_text I18n.t('spree.shopping_cart') }
      click_button I18n.t("spree.checkout")

      expect(page).to have_content(I18n.t("spree.guest_user_account"))

      within('#guest_checkout') { fill_in I18n.t("spree.email"), with: 'spree@test.com' }
      click_button I18n.t("spree.continue")

      expect(page).to have_text(I18n.t("spree.billing_address"))
      expect(page).to have_text(/Shipping Address/i)

      fill_addresses_fields_with(address)
      click_button I18n.t("spree.save_and_continue")

      click_button I18n.t("spree.save_and_continue")
      click_button I18n.t("spree.save_and_continue")
      check I18n.t("spree.agree_to_terms_of_service")
      click_button I18n.t("spree.place_order")

      expect(page).to have_text I18n.t('spree.order_processed_successfully')
    end

    scenario 'associate an uncompleted guest order with user after logging in' do
      user = create(:user, email: 'email@person.com', password: 'password', password_confirmation: 'password')
      click_link 'Solidus hoodie'
      click_button I18n.t("spree.add_to_cart")

      visit login_path
      fill_in I18n.t("spree.email"), with: user.email
      fill_in "#{I18n.t("spree.password")}:", with: user.password
      click_button I18n.t("spree.login")
      click_link I18n.t("spree.cart")

      expect(page).to have_text 'Solidus hoodie'
      within('h1') { expect(page).to have_text I18n.t('spree.shopping_cart') }

      click_button I18n.t("spree.checkout")

      fill_addresses_fields_with(address)
      click_button I18n.t("spree.save_and_continue")

      click_button I18n.t("spree.save_and_continue")
      click_button I18n.t("spree.save_and_continue")
      check I18n.t("spree.agree_to_terms_of_service")
      click_button I18n.t("spree.place_order")

      expect(page).to have_text I18n.t('spree.order_processed_successfully')
      expect(Spree::Order.first.user).to eq user
    end

    # Regression test for #890
    scenario 'associate an incomplete guest order with user after successful password reset' do
      create(:user, email: 'email@person.com', password: 'password', password_confirmation: 'password')
      click_link 'Solidus hoodie'
      click_button I18n.t("spree.add_to_cart")

      visit login_path
      click_link I18n.t("spree.forgot_password")
      fill_in 'spree_user_email', with: 'email@person.com'
      click_button I18n.t("spree.reset_password")

      # Need to do this now because the token stored in the DB is the encrypted version
      # The 'plain-text' version is sent in the email and there's one way to get that!
      reset_password_email = ActionMailer::Base.deliveries.first
      token_url_regex = /\/user\/password\/edit\?reset_password_token=(.*)$/
      token = token_url_regex.match(reset_password_email.body.to_s)[1]

      visit edit_spree_user_password_path(reset_password_token: token)
      fill_in "#{I18n.t("spree.password")}:", with: 'password'
      fill_in I18n.t("spree.confirm_password"), with: 'password'
      click_button I18n.t("spree.update")

      click_link I18n.t("spree.cart")
      click_button I18n.t("spree.checkout")

      fill_addresses_fields_with(address)
      click_button I18n.t("spree.save_and_continue")

      expect(page).not_to have_text 'Email is invalid'
    end

    scenario 'allow a user to register during checkout' do
      click_link 'Solidus hoodie'
      click_button I18n.t("spree.add_to_cart")
      click_button I18n.t("spree.checkout")

      within '#existing-customer' do
        click_link I18n.t("spree.create_a_new_account")
      end

      fill_in I18n.t("spree.email"), with: 'email@person.com'
      fill_in "#{I18n.t("spree.password")}:", with: 'spree123'
      fill_in I18n.t("spree.confirm_password"), with: 'spree123'
      click_button I18n.t("spree.create")

      expect(page).to have_text I18n.t('devise.user_registrations.signed_up')

      fill_addresses_fields_with(address)
      click_button I18n.t("spree.save_and_continue")

      click_button I18n.t("spree.save_and_continue")
      click_button I18n.t("spree.save_and_continue")
      check I18n.t("spree.agree_to_terms_of_service")
      click_button I18n.t("spree.place_order")

      expect(page).to have_text I18n.t('spree.order_processed_successfully')
      expect(Spree::Order.first.user).to eq Spree::User.find_by(email: 'email@person.com')
    end
  end
end
