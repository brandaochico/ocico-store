# frozen_string_literal: true

# Re-creates a product image variant whose file has gone missing.
#
# Active Storage records a variant before uploading its file. If generation is
# cut short in between — a 3000x4000 photo resized during a request while a
# deploy stops that container — the record stays without a file, and from
# then on Active Storage believes the variant exists and serves a URL that
# 404s forever (seen on 2026-11-20: three variants of one product). Here a
# variant whose record has no file behind it is dropped and generated again,
# on the next render. The check is one stat on the local disk service.
module SelfHealingImageVariants
  def variant(style = nil)
    processed = super
    blob = processed.try(:image)&.blob
    return processed if blob.nil? || blob.service.exist?(blob.key)

    Rails.logger.warn("[images] variant #{blob.key} of attachment #{@attachment.id} has no file; regenerating")
    processed.image.record.destroy
    super
  end

  ::Spree::ActiveStorageAdapter::Attachment.prepend self
end
