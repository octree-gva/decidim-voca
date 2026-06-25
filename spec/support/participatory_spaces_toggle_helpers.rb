# frozen_string_literal: true

module ParticipatorySpacesToggleHelpers
  def seed_participatory_space_toggle(organization, module_name, enabled:)
    Decidim::Toggle.save_config!(
      organization,
      module_name,
      { enabled: }
    )
  end
end

RSpec.configure do |config|
  config.include ParticipatorySpacesToggleHelpers
end
