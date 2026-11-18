# frozen_string_literal: true

require "rails_helper"

RSpec.describe CollectionSpritesHelper, type: :helper do
  let(:taxon) { instance_double(Spree::Taxon, permalink: "colecoes/151") }

  let(:sprites_dir) { Pathname(Dir.mktmpdir) }

  before { stub_const("CollectionSpritesHelper::SPRITES_DIR", sprites_dir) }
  after { FileUtils.remove_entry(sprites_dir) }

  it "returns the sprite when its file is present" do
    FileUtils.touch(sprites_dir.join("151.png"))

    expect(helper.collection_sprite_for(taxon)).to include(file: "151.png")
  end

  # The sprites are git-ignored, so an image built from a clone has none —
  # that must render a card without art, not a 500.
  it "returns nil when the file isn't on this machine" do
    expect(helper.collection_sprite_for(taxon)).to be_nil
  end

  it "returns nil for a collection without a sprite" do
    other = instance_double(Spree::Taxon, permalink: "colecoes/unknown-set")

    expect(helper.collection_sprite_for(other)).to be_nil
  end
end
