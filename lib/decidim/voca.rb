# frozen_string_literal: true

require_relative "voca/installation"

require_relative "voca/deepl" if Decidim::Voca::Installation.deepl_installed?

require_relative "voca/engine"
require_relative "voca/configuration"
require_relative "voca/overrides/organization/organization_model_overrides"
require_relative "voca/overrides/next_gen_images/decidim_viewmodel"
require_relative "voca/overrides/next_gen_images/override_for_has_one_attached"
require_relative "voca/overrides/next_gen_images/override_cell_resource_image_url"
require_relative "voca/overrides/next_gen_images/image_tag_overrides"
require_relative "voca/overrides/next_gen_images/proposal_g_cell_override"
require_relative "voca/overrides/mod_secure/user_profile_verification_override"
require_relative "voca/overrides/geolocated_proposals/create_proposal_overrides"
require_relative "voca/overrides/geolocated_proposals/map_autocomplete_builder_overrides"
require_relative "voca/overrides/meetings_controller_overrides"
require_relative "voca/overrides/etherpad_overrides"
require_relative "voca/overrides/proposal_serializer_overrides"
require_relative "voca/overrides/user_group_form_overrides"
require_relative "voca/overrides/resource_presenter_overrides"
require_relative "voca/overrides/sanitize_helper_overrides"
require_relative "voca/overrides/address_cell_overrides"
require_relative "voca/overrides/card_metadata_cell_overrides"
require_relative "voca/overrides/footer/footer_topic_cell_overrides"
require_relative "voca/overrides/footer/footer_menu_presenter"
require_relative "voca/machine_translation/translate_string"
require_relative "voca/component_setting_manifest"
require_relative "voca/component_setting_pending_locales"
require_relative "voca/component_translated_settings_machine_translation"
require_relative "voca/sync_locales"
require_relative "voca/overrides/system/system_organization_update_form"
require_relative "voca/overrides/extra_data_cell_overrides"
require_relative "voca/overrides/check_boxes_tree_helper_overrides"
require_relative "voca/overrides/attachment_form_overrides"
require_relative "voca/overrides/attachment_overrides"
require_relative "voca/overrides/update_content_block_overrides"
require_relative "voca/overrides/copy_assembly_overrides"
require_relative "voca/overrides/notify_proposal_answer_overrides"
require_relative "voca/overrides/participatory_process_groups_controller_overrides"
require_relative "voca/overrides/mod_secure/conversation_uuid"
require_relative "voca/overrides/mod_secure/conversation_controller_overrides"
require_relative "voca/overrides/mod_secure/conversation_sanitize"
require_relative "voca/open_telemetry/request_env"
require_relative "voca/open_telemetry/logger_provider_resolver"
require_relative "voca/open_telemetry/logs_setup"
require_relative "voca/open_telemetry/decidim_context_attributes"
require_relative "voca/open_telemetry/otel_decidim_context"
require_relative "voca/open_telemetry/otel_error_subscriber"
require_relative "voca/open_telemetry/otel_logger_subscriber"
require "good_job/engine"

module Decidim
  module Voca
    UUID_REGEXP = /[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/
    autoload :OpenTelemetryConfigurator, "decidim/voca/open_telemetry_configurator"
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

    def self.weglot?
      # Prefer deepl over weglot
      configuration.enable_weglot && !Installation.deepl_enabled?
    end

    def self.weglot_cache?
      configuration.enable_weglot_cache
    end

    def self.minimalistic_deepl?
      Installation.deepl_enabled? && configuration.enable_minimalistic_deepl
    end

    def self.opentelemetry_traces_endpoint
      @opentelemetry_traces_endpoint ||= begin
        ENV.fetch(
          "OTEL_EXPORTER_OTLP_TRACES_ENDPOINT",
          "#{ENV.fetch("OTEL_EXPORTER_OTLP_ENDPOINT")}/v1/traces"
        )
      rescue KeyError
        ""
      end
    end

    def self.opentelemetry_logs_endpoint
      @opentelemetry_logs_endpoint ||= begin
        ENV.fetch(
          "OTEL_EXPORTER_OTLP_LOGS_ENDPOINT",
          "#{ENV.fetch("OTEL_EXPORTER_OTLP_ENDPOINT")}/v1/logs"
        )
      rescue KeyError
        ""
      end
    end

    def self.opentelemetry_enabled?
      return false unless defined?(::OpenTelemetry)

      endpoint = opentelemetry_traces_endpoint
      endpoint.present? && endpoint.strip.present?
    end

    def self.opentelemetry_logger_provider
      @opentelemetry_logger_provider
    end

    def self.opentelemetry_logger_provider=(provider)
      @opentelemetry_logger_provider = provider
    end

    def self.opentelemetry_flush_logs(timeout: 5)
      return unless opentelemetry_logger_provider

      begin
        processors = opentelemetry_logger_provider.instance_variable_get(:@log_record_processors) || []
        processors.each do |processor|
          processor.force_flush(timeout:) if processor.respond_to?(:force_flush)
        end
        true
      rescue StandardError => e
        Rails.logger.warn("[OpenTelemetry] Failed to flush logs: #{e.message}") if defined?(Rails)
        false
      end
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
