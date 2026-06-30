# frozen_string_literal: true

module Decidim
  module Voca
    module DeepL
      # Single source of truth for VOCA `merge_translatable_fields` widenings when DeepL is enabled.
      # See {#apply_mergeable_fields!}; component `settings` / step locale hashes stay in ComponentSettingSync.
      class EngineConfig
        # @return [Array<Hash>] Each row: :class_name (String), :fields (Array<String>),
        #   :include_translatable_resource (Boolean, default false), :if (optional proc — skip row when falsey).
        MERGEABLE_FIELD_REGISTRY = [
          {
            class_name: "Decidim::Component",
            include_translatable_resource: true,
            component_settings_mt: true,
            fields: %w(name)
          },
          {
            class_name: "Decidim::Budgets::Budget",
            include_translatable_resource: true,
            fields: %w(title description)
          },
          {
            class_name: "Decidim::Proposals::ProposalState",
            fields: %w(announcement_title)
          },
          {
            class_name: "Decidim::Proposals::Proposal",
            fields: %w(answer cost_report execution_period)
          },
          {
            class_name: "Decidim::Organization",
            fields: %w(short_name)
          },
          {
            class_name: "Decidim::Category",
            fields: %w(description)
          },
          {
            class_name: "Decidim::Forms::DisplayCondition",
            include_translatable_resource: true,
            fields: %w(condition_value)
          },
          {
            class_name: "Decidim::Templates::Template",
            include_translatable_resource: true,
            if: -> { Decidim::Voca::Installation.decidim_templates_installed? },
            fields: %w(name description)
          }
        ].freeze

        class << self
          # Wire model hooks and overrides that must be loaded after the app is initialized.
          # @param config [Rails::Application] host app (+Rails.application+; first block arg of +initializer+)
          def initialize!
            return unless Decidim::Voca::Installation.deepl_enabled?

            configure_deepl!
            configure_machine_translation!
            Rails.application.config.middleware.use ::Decidim::Voca::DeepL::Middleware

            ActiveSupport.on_load(:active_job) { include Decidim::Voca::DeepL::ActiveJobContext }
            Rails.logger.warn("DeepL is enabled, preparing minimalistic machine translation") if Decidim::Voca.minimalistic_deepl?
          end

          # Configure the DeepL SDK + Decidim machine translation config (+middleware, ActiveJob hook).
          # Called from {Decidim::Voca::Engine}'s +decidim.voca.deepl+ initializer (middleware stack not frozen yet).
          def configure!
            return unless Decidim::Voca::Installation.deepl_enabled?

            apply_mergeable_fields!
            fix_accountability_timeline_entry_translatable_fields!

            unless Decidim::MachineTranslationResourceJob.ancestors.include?(Decidim::Voca::MachineTranslationResourceJobVoca)
              Decidim::MachineTranslationResourceJob.prepend(Decidim::Voca::MachineTranslationResourceJobVoca)
            end

            if Decidim::Voca.minimalistic_deepl?
              ::Decidim::TranslationBarCell.include(Decidim::Voca::DeepL::TranslationBarOverrides)
              ::Decidim::FormBuilder.include(Decidim::Voca::DeepL::DeepLFormBuilderOverrides)
            end
          end

          def apply_mergeable_fields!
            MERGEABLE_FIELD_REGISTRY.each { |row| apply_mergeable_registry_row!(row) }
          end

          private

          def apply_mergeable_registry_row!(row)
            return if row[:if] && !row[:if].call

            klass = row[:class_name].safe_constantize
            return unless klass

            maybe_include_component_settings_mt!(klass, row)
            maybe_include_translatable_resource!(klass, row)
            merge_applicable_column_fields!(klass, row)
          end

          def maybe_include_component_settings_mt!(klass, row)
            return unless row[:component_settings_mt]
            return if klass.included_modules.include?(Decidim::Voca::ComponentTranslatedSettingsMachineTranslation)

            klass.include(Decidim::Voca::ComponentTranslatedSettingsMachineTranslation)
          end

          def maybe_include_translatable_resource!(klass, row)
            return unless row[:include_translatable_resource]
            return if klass.included_modules.include?(Decidim::TranslatableResource)

            klass.include(Decidim::TranslatableResource)
          end

          def merge_applicable_column_fields!(klass, row)
            return unless database_table_ready?(klass)

            applicable = row[:fields].map(&:to_s).select { |f| klass.column_names.include?(f) }
            Decidim::Voca.merge_translatable_fields(klass, *applicable) if applicable.any?
          end

          def database_table_ready?(klass)
            klass.table_exists?
          rescue ActiveRecord::NoDatabaseError, ActiveRecord::ConnectionNotEstablished, PG::ConnectionBad
            false
          end

          def fix_accountability_timeline_entry_translatable_fields!
            return unless defined?(Decidim::Accountability::TimelineEntry)

            Decidim::Accountability::TimelineEntry.translatable_fields(:title, :description)
          end

          def configure_deepl!
            require "deepl"
            ::DeepL.configure do |deepl|
              deepl.auth_key = ENV.fetch("DECIDIM_DEEPL_API_KEY", "")
              deepl.host = ENV.fetch("DECIDIM_DEEPL_HOST", "https://api.deepl.com")
              deepl.version = ENV.fetch("DECIDIM_DEEPL_VERSION", "v2")
            end
          end

          def configure_machine_translation!
            Decidim.configure do |decidim_config|
              decidim_config.enable_machine_translations = true
              decidim_config.machine_translation_service = "Decidim::Voca::DeepL::MachineTranslator"
              decidim_config.machine_translation_delay = 3.seconds
            end
          end
        end
      end
    end
  end
end
