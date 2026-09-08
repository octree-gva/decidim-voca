# frozen_string_literal: true

class EnableVocaDefaultsUserFieldsCustomization < ActiveRecord::Migration[7.0]
  def up
    each_organization { |organization| save_enabled(organization, true) }
  end

  def down
    each_organization { |organization| save_enabled(organization, false) }
  end

  private

  def each_organization(&)
    return unless toggle_ready?

    Decidim::Organization.find_each(&)
  end

  def toggle_ready?
    return false unless Gem.loaded_specs.has_key?("decidim-toggle")

    connection.table_exists?("decidim_toggle_organization_module_configs")
  end

  def save_enabled(organization, value)
    Decidim::Toggle.save_config!(
      organization,
      "custom_user_fields",
      { "voca_defaults_enabled" => value }
    )
  end
end
