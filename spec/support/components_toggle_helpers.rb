# frozen_string_literal: true

module ComponentsToggleHelpers
  def seed_component_toggle(organization, component_or_module, enabled:)
    component = resolve_component_key(component_or_module)

    Decidim::Toggle.save_config!(
      organization,
      Decidim::Voca::Components::MODULE_NAME,
      { "#{component}_enabled" => enabled }
    )
  end

  def resolve_component_key(component_or_module)
    key = component_or_module.to_sym
    return key if Decidim::Voca::Components::COMPONENTS.has_key?(key)

    Decidim::Voca::Components.component_for_module_name(component_or_module) ||
      raise(ArgumentError, "Unknown component: #{component_or_module}")
  end
end

RSpec.configure do |config|
  config.include ComponentsToggleHelpers
end
