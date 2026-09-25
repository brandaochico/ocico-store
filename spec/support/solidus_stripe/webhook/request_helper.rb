# frozen_string_literal: true

module SolidusStripe
  module Webhook
    # Helpers to simulate incoming Stripe webhook from request specs.
    #
    # It's a lightweight alternative to configuring `stripe-cli` in the automated tests.
    module RequestHelper
      # @param context [SolidusStripe::Webhook::EventWithContextFactory]
      # @param payment_method [SolidusStripe::PaymentMethod]
      # @param timestamp [Time] It allows to override the timestamp in the context
      #   to simulate an invalid request.
      # @param slug [String] It allows to override the slug in the payment
      #   method to simulate an invalid request.
      def webhook_request(context, timestamp: context.timestamp)
        post "/solidus_stripe/#{context.slug}/webhooks",
          params: context.json,
          headers: {
            webhook_signature_header_key => webhook_signature_header(context, timestamp: timestamp),
            # Send the payload as a raw JSON body so `request.body.read` matches
            # exactly what the Stripe signature was computed over. Without an
            # explicit content type Rack form-decodes the JSON string and
            # signature verification fails with a 400.
            "CONTENT_TYPE" => "application/json"
          }
      end

      private

      def webhook_signature_header_key
        SolidusStripe::WebhooksController::SIGNATURE_HEADER
      end

      def webhook_signature_header(context, timestamp:)
        context.signature_header(timestamp: timestamp)
      end
    end
  end
end
