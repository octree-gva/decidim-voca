# frozen_string_literal: true

module Decidim
  module Voca
    module DeepL
      class EngineConfig
        class << self
          # Wire model hooks and overrides that must be loaded after the app is initialized.
          def initialize!(engine)
            engine.config.to_prepare do
              require_relative "../machine_translation_resource_job_voca"

              Decidim::Component.include(Decidim::Voca::ComponentTranslatedSettingsMachineTranslation)

              next unless Decidim::Voca.deepl_enabled?

              Decidim::Component.include(Decidim::TranslatableResource)
              Decidim::Voca.merge_translatable_fields(Decidim::Component, "name")

              Decidim::Budgets::Budget.include(Decidim::TranslatableResource)
              Decidim::Voca.merge_translatable_fields(Decidim::Budgets::Budget, "title", "description")
              Decidim::Voca.merge_translatable_fields(
                Decidim::Proposals::ProposalState,
                "title",
                "announcement_title"
              )

              if Decidim::Voca::Installation.decidim_templates_installed?
                Decidim::Templates::Template.include(Decidim::TranslatableResource)
                Decidim::Voca.merge_translatable_fields(Decidim::Templates::Template, "name", "description")
              end

              Decidim::MachineTranslationResourceJob.prepend(Decidim::Voca::MachineTranslationResourceJobVoca)

              if Decidim::Voca.minimalistic_deepl?
                ::Decidim::TranslationBarCell.include(Decidim::Voca::DeepL::TranslationBarOverrides)
                ::Decidim::FormBuilder.include(Decidim::Voca::DeepL::DeepLFormBuilderOverrides)
              end
            end
          end

          # Configure the DeepL SDK + Decidim machine translation config.
          def configure!(engine)
            engine.initializer "decidim.voca.deepl", after: :load_config_initializers do
              next unless Decidim::Voca.deepl_enabled?

              require "deepl"
              ::DeepL.configure do |config|
                config.auth_key = ENV.fetch("DECIDIM_DEEPL_API_KEY", "")
                config.host = ENV.fetch("DECIDIM_DEEPL_HOST", "https://api.deepl.com")
                config.version = ENV.fetch("DECIDIM_DEEPL_VERSION", "v2")
              end

              Rails.application.config.middleware.use ::Decidim::Voca::DeepL::Middleware
              Decidim.configure do |decidim_config|
                decidim_config.enable_machine_translations = true
                decidim_config.machine_translation_service = "Decidim::Voca::DeepL::MachineTranslator"
                decidim_config.machine_translation_delay = 3.seconds
              end

              ActiveSupport.on_load(:active_job) { include Decidim::Voca::DeepL::ActiveJobContext }
              Rails.logger.warn("DeepL is enabled, preparing minimalistic machine translation") if Decidim::Voca.minimalistic_deepl?
            end
          end
        end
      end
    end
  end
end

