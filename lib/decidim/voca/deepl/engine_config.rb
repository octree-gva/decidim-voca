# frozen_string_literal: true

module Decidim
  module Voca
    module DeepL
      class EngineConfig
        class << self
          # Wire model hooks and overrides that must be loaded after the app is initialized.
          # @param config [Rails::Application] host app (+Rails.application+; first block arg of +initializer+)
          def initialize!(config)
            config.config.to_prepare do
              Decidim::Component.include(Decidim::Voca::ComponentTranslatedSettingsMachineTranslation)

              next unless Decidim::Voca::Installation.deepl_enabled?

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

          # Configure the DeepL SDK + Decidim machine translation config (+middleware, ActiveJob hook).
          # Called from {Decidim::Voca::Engine}'s +decidim.voca.deepl+ initializer (middleware stack not frozen yet).
          def configure!
            return unless Decidim::Voca::Installation.deepl_enabled?

            configure_deepl!
            Rails.application.config.middleware.use ::Decidim::Voca::DeepL::Middleware
            configure_machine_translation!

            ActiveSupport.on_load(:active_job) { include Decidim::Voca::DeepL::ActiveJobContext }
            Rails.logger.warn("DeepL is enabled, preparing minimalistic machine translation") if Decidim::Voca.minimalistic_deepl?
          end

          private

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
