require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_mailbox/engine"
require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module OcicoStore
  class Application < Rails::Application
    if defined?(FactoryBotRails)
      initializer after: "factory_bot.set_factory_paths" do
        require "spree/testing_support/factory_bot"

        # The paths for Solidus' core factories.
        solidus_paths = Spree::TestingSupport::FactoryBot.definition_file_paths

        # Optional: Any factories you want to require from extensions.
        extension_paths = [
          # MySolidusExtension::Engine.root.join("lib/my_solidus_extension/testing_support/factories"),
          # or individually:
          # MySolidusExtension::Engine.root.join("lib/my_solidus_extension/testing_support/factories/resource.rb"),
        ]

        # Your application's own factories.
        app_paths = [
          Rails.root.join("spec/factories")
        ]

        FactoryBot.definition_file_paths = solidus_paths + extension_paths + app_paths
      end
    end
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Don't generate system test files.
    config.generators.system_tests = nil

    # Solidus's default asset variant styles use vips-only pipeline steps (e.g. `.saver`),
    # so this must stay on :vips (the Rails 8 default) — requires the libvips system library.

    # pt-BR is the only active locale for now; fall back to Solidus/Devise's bundled
    # :en translations for gem-owned strings we haven't overridden yet.
    config.i18n.default_locale = :"pt-BR"
    config.i18n.available_locales = [ :"pt-BR", :en ]
    # `true` would fall back to default_locale, which IS pt-BR here — no-op.
    # Explicitly fall back to :en so gem-owned strings we haven't translated still render.
    config.i18n.fallbacks = { "pt-BR" => [ :en ] }

    # sassc-rails auto-sets this to :sass outside development, which makes Sprockets
    # run our already-built Tailwind v4 output (and any other plain .css) through the
    # legacy libsass compressor — it can't parse modern syntax like range media
    # queries and breaks every page in test/production. We don't need Sprockets to
    # compress CSS it doesn't own; Tailwind's own CLI already minifies its output.
    config.assets.css_compressor = nil
  end
end
