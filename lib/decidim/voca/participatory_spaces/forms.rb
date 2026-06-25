# frozen_string_literal: true

module Decidim
  module Voca
    module ParticipatorySpaces
      module ToggleForm
        extend ActiveSupport::Concern

        included do
          include Decidim::Toggle::ModuleConfigForm
          include Decidim::Toggle::ExposeAttributesToJs

          mimic :organization

          attribute :enabled, :boolean

          expose_to_javascript :enabled
        end
      end

      class InitiativesToggleForm < Decidim::Form
        include ToggleForm

        self.module_config_name = "decidim_initiatives"
      end

      class ConferencesToggleForm < Decidim::Form
        include ToggleForm

        self.module_config_name = "decidim_conferences"
      end

      class ParticipatoryProcessesToggleForm < Decidim::Form
        include ToggleForm

        self.module_config_name = "decidim_participatory_processes"
      end

      class AssembliesToggleForm < Decidim::Form
        include ToggleForm

        self.module_config_name = "decidim_assemblies"
      end

      JS_TOGGLE_FORMS = {
        decidim_initiatives: InitiativesToggleForm,
        decidim_conferences: ConferencesToggleForm,
        decidim_participatory_processes: ParticipatoryProcessesToggleForm,
        decidim_assemblies: AssembliesToggleForm
      }.freeze

      class ConfigForm < Decidim::Form
        attribute :initiatives_enabled, :boolean
        attribute :conferences_enabled, :boolean
        attribute :participatory_processes_enabled, :boolean
        attribute :assemblies_enabled, :boolean

        def self.from_model(organization)
          from_params(
            FORM_ATTRIBUTES.transform_values do |module_name|
              ParticipatorySpaces.enabled?(organization, module_name)
            end
          ).with_context(current_organization: organization)
        end
      end

      class UpdateConfigCommand < Decidim::Command
        def initialize(organization, form)
          @organization = organization
          @form = form
        end

        def call
          return broadcast(:invalid) if form.invalid?

          FORM_ATTRIBUTES.each do |attribute, module_name|
            Decidim::Toggle.save_config!(
              organization,
              module_name,
              { enabled: form.public_send(attribute) }
            )
          end

          broadcast(:ok)
        rescue ActiveRecord::RecordInvalid
          broadcast(:invalid)
        end

        private

        attr_reader :organization, :form
      end
    end
  end
end
