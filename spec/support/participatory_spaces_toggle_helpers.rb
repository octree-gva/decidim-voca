# frozen_string_literal: true

module ParticipatorySpacesToggleHelpers
  def seed_participatory_space_toggle(organization, space_or_module, enabled:)
    space = resolve_participatory_space_key(space_or_module)

    Decidim::Toggle.save_config!(
      organization,
      Decidim::Voca::ParticipatorySpaces::MODULE_NAME,
      { "#{space}_enabled" => enabled }
    )
  end

  def resolve_participatory_space_key(space_or_module)
    key = space_or_module.to_sym
    return key if Decidim::Voca::ParticipatorySpaces::SPACES.key?(key)

    Decidim::Voca::ParticipatorySpaces.space_for_module_name(space_or_module) ||
      raise(ArgumentError, "Unknown participatory space: #{space_or_module}")
  end
end

RSpec.configure do |config|
  config.include ParticipatorySpacesToggleHelpers
end
