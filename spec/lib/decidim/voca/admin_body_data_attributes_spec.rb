# frozen_string_literal: true

require "spec_helper"

describe Decidim::Voca::AdminBodyDataAttributes do
  describe ".deface_attributes" do
    subject(:attributes) { described_class.deface_attributes }

    it "merges participatory space and component data attributes" do
      space_keys = Decidim::Voca::ParticipatorySpaces::BodyDataAttributes.deface_attributes.keys
      component_keys = Decidim::Voca::Components::BodyDataAttributes.deface_attributes.keys

      expect(attributes.keys).to match_array(space_keys + component_keys)
    end

    it "includes awesome map and iframe component toggles" do
      expect(attributes).to include("data-awesome-map-enabled")
      expect(attributes).to include("data-awesome-iframe-enabled")
    end
  end
end
