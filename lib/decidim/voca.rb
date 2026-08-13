# frozen_string_literal: true


require_relative "voca/deepl"

require_relative "voca/engine"
require_relative "voca/configuration"
require_relative "voca/overrides/searches_controller_overrides"
require_relative "voca/overrides/next_gen_images/decidim_viewmodel"
require_relative "voca/overrides/next_gen_images/override_for_has_one_attached"
require_relative "voca/overrides/next_gen_images/override_cell_resource_image_url"
require_relative "voca/overrides/next_gen_images/image_tag_overrides"
require_relative "voca/overrides/next_gen_images/proposal_g_cell_override"
require_relative "voca/overrides/mod_secure/user_profile_verification_override"
require_relative "voca/overrides/geolocated_proposals/create_proposal_overrides"
require_relative "voca/overrides/geolocated_proposals/map_autocomplete_builder_overrides"
require_relative "voca/overrides/proposal_serializer_overrides"
require_relative "voca/machine_translation/translate_string"
require_relative "voca/machine_translation_resource_job_voca"
require_relative "voca/component_setting_manifest"
require_relative "voca/component_setting_pending_locales"
require_relative "voca/component_translated_settings_machine_translation"
require_relative "voca/sync_locales"
require_relative "voca/overrides/system/system_organization_update_form"
require_relative "voca/overrides/mod_secure/conversation_uuid"
require_relative "voca/overrides/mod_secure/conversation_controller_overrides"
require_relative "voca/overrides/mod_secure/conversation_sanitize"
require "good_job/engine"

module Decidim
  module Voca
    UUID_REGEXP = /[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/
    autoload :RackAttackConfigurator, "decidim/voca/rack_attack_configurator"
    autoload :UserFieldsConfigurator, "decidim/voca/user_fields_configurator"
    def self.configuration
      @configuration ||= Configuration.new
    end

    def self.configure
      yield configuration
    end

    def self.next_gen_images?
      configuration.enable_next_gen_images
    end

    def self.decidim_awesome?
      Gem.loaded_specs.has_key?("decidim-decidim_awesome")
    end

    def self.weglot?
      # Prefer deepl over weglot
      configuration.enable_weglot && !Installation.deepl_enabled?
    end

    def self.weglot_cache?
      configuration.enable_weglot_cache
    end

    def self.minimalistic_deepl?
      configuration.enable_minimalistic_deepl
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
