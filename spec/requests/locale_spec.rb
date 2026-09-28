# frozen_string_literal: true

require 'solidus_starter_frontend_spec_helper'

RSpec.describe 'Locale', type: :request do
  include_context "fr locale"

  context 'switch_to_locale specified' do
    context "available locale" do
      it 'sets locale and redirects' do
        get locale_set_path, params: { switch_to_locale: 'fr' }
        expect(I18n.locale).to eq :fr
        expect(response).to redirect_to('/')
        expect(session[:locale]).to eq('fr')
        expect(flash[:notice]).to eq(I18n.t("spree.locale_changed"))
      end
    end

    context "unavailable locale" do
      it 'does not change locale and redirects' do
        get locale_set_path, params: { switch_to_locale: 'klingon' }
        expect(I18n.locale).to eq I18n.default_locale
        expect(response).to redirect_to('/')
        expect(flash[:error]).to eq(I18n.t("spree.locale_not_changed"))
      end
    end
  end

  context 'locale specified' do
    context "available locale" do
      it 'sets locale and redirects' do
        get locale_set_path, params: { locale: 'fr' }
        expect(I18n.locale).to eq :fr
        expect(response).to redirect_to('/')
        expect(flash[:notice]).to eq(I18n.t("spree.locale_changed"))
      end
    end

    context "unavailable locale" do
      it 'does not change locale and redirects' do
        get locale_set_path, params: { locale: 'klingon' }
        expect(I18n.locale).to eq I18n.default_locale
        expect(response).to redirect_to('/')
        expect(flash[:error]).to eq(I18n.t("spree.locale_not_changed"))
      end
    end
  end

  context 'when a visitor has chosen no locale' do
    let!(:store) { create(:store) }

    # I18n.locale is thread-local and is not reset between requests. Solidus's
    # set_user_language consults StoreController#config_locale before falling
    # back to I18n.default_locale, so if config_locale reports "whatever is set
    # right now", a fresh visitor inherits the locale left behind by the last
    # request on that Puma thread — and set_user_language writes it into their
    # session, so it sticks. This simulates that leftover state.
    it 'serves the default locale rather than whatever the last request left set' do
      I18n.locale = :fr

      get root_path

      expect(I18n.locale).to eq I18n.default_locale
      expect(response.body).to include(%(<html lang="#{I18n.default_locale}"))
    end
  end

  context 'both locale and switch_to_locale specified' do
    it 'uses switch_to_locale value' do
      get locale_set_path, params: { locale: 'en', switch_to_locale: 'fr' }
      expect(I18n.locale).to eq :fr
      expect(response).to redirect_to('/')
      expect(flash[:notice]).to eq(I18n.t("spree.locale_changed"))
    end
  end
end
