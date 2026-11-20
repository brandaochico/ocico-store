# frozen_string_literal: true

# Product image URLs that never expire.
#
# Solidus's adapter returns the variant's service URL — for the Disk service a
# signed /rails/active_storage/disk/… link valid for five minutes. Pages are
# fragment-cached with those links inside, so five minutes after a page was
# cached its images 404'd (seen in production on 2026-11-20, twice). The proxy
# route instead is permanent: Rails streams the file and marks the response
# cacheable forever (the variant key changes whenever the image does), so
# browsers and Thruster keep it and cached HTML stays valid.
module PermanentImageUrls
  def url(style = nil)
    variant = variant(style)
    variant && Rails.application.routes.url_helpers.rails_storage_proxy_path(variant, only_path: true)
  end

  ::Spree::ActiveStorageAdapter::Attachment.prepend self
end
