# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = "1.0"

# Add additional assets to the asset load path.
# Rails.application.config.assets.paths << Emoji.images_path
Rails.application.config.assets.precompile += [ "solidus_starter_frontend_manifest.js" ]
Rails.application.config.assets.paths << Rails.root.join("app", "assets", "stylesheets", "fonts")

# One fixed manifest name for every build. By default Sprockets names it
# .sprockets-manifest-<random>.json, and Kamal's asset bridging (asset_path in
# config/deploy.yml) copies the previous release's public/assets — manifest
# included — next to the new one. With two manifests in the directory Sprockets
# reads whichever it finds first, so after a deploy pages could link the
# *previous* build's CSS and JS (seen on 2026-11-20: the new product gallery
# rendered unstyled). With a fixed name each build overwrites the same file,
# and the bridging copy (no-clobber) never replaces the new one.
Rails.application.config.assets.manifest = Rails.root.join("public/assets/.sprockets-manifest.json")
