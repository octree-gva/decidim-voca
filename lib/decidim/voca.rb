# frozen_string_literal: true

require_relative "voca/deepl"

require_relative "voca/engine"
require_relative "voca/overrides/searches_controller_overrides"
require_relative "voca/overrides/next_gen_images/decidim_viewmodel"
require_relative "voca/overrides/next_gen_images/override_for_has_one_attached"
require_relative "voca/overrides/next_gen_images/override_cell_resource_image_url"
require_relative "voca/overrides/next_gen_images/image_tag_overrides"
require_relative "voca/overrides/next_gen_images/proposal_g_cell_override"
require_relative "voca/overrides/mod_secure/user_profile_verification_override"
require_relative "voca/overrides/resource_presenter_overrides"
require_relative "voca/overrides/sanitize_helper_overrides"
require_relative "voca/machine_translation/translate_string"
require_relative "voca/machine_translation_resource_job_voca"
require_relative "voca/component_setting_manifest"
require_relative "voca/component_setting_pending_locales"
require_relative "voca/component_translated_settings_machine_translation"
require_relative "voca/sync_locales"
require_relative "voca/overrides/mod_secure/conversation_uuid"
require_relative "voca/overrides/mod_secure/conversation_controller_overrides"
require_relative "voca/overrides/mod_secure/conversation_sanitize"
require_relative "voca/organization_voca_extensions"
require "good_job/engine"

module Decidim
  module Voca
    UUID_REGEXP = /[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/

    def self.decidim_awesome?
      Gem.loaded_specs.has_key?("decidim-decidim_awesome")
    end

    # Decidim::TranslatableResource.translatable_fields replaces the entire list.
    # Append VOCA field names without dropping fields registered elsewhere.
    def self.merge_translatable_fields(klass, *fields)
      existing = klass.translatable_fields_list
      existing = existing ? existing.map(&:to_s) : []
      additions = fields.flatten.map(&:to_s).reject { |f| existing.include?(f) }
      return if additions.empty?

      # Open class and set the translatable fields
      klass.translatable_fields(*(existing + additions))
    end
  end
end
