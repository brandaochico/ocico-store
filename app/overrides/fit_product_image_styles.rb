# frozen_string_literal: true

# Lets a product image style mean "fit the whole image inside this box".
#
# Solidus maps style strings to two transformations only: "WxH^" crops to fill
# the box (resize_to_fill), anything else shrinks to stay within it but never
# enlarges (resize_to_limit). Product photos — cards especially, which are
# portrait — must be shown whole, never cropped, and at a consistent size, so
# here a plain "WxH" (no suffix) becomes resize_to_fit: scaled up or down until
# it touches the box on one side, aspect ratio kept, nothing cut. "^" and ">"
# keep Solidus's meaning. Styles live in config/initializers/spree.rb.
module FitProductImageStyles
  private

  def imagemagick_to_image_processing_definition(definition)
    return super unless definition.match?(/\A\d+x\d+\z/)

    { resize_to_fit: definition.split("x").map(&:to_i) }
  end

  ::Spree::ActiveStorageAdapter::Attachment.prepend self
end
