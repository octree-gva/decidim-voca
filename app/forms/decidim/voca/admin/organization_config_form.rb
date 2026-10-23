# frozen_string_literal: true

module Decidim
  module Voca
    module Admin
      class OrganizationConfigForm < Decidim::Form
        include Decidim::Toggle::ModuleConfigForm
        include Decidim::Toggle::ExposeAttributesToJs

        self.module_config_name = Decidim::Voca::MODULE_NAME

        mimic :organization

        attribute :deepl_enabled, Boolean, default: true
        attribute :minimalistic_deepl_enabled, Boolean, default: true
        attribute :weglot_enabled, Boolean, default: false
        attribute :weglot_api_key, String, default: ::Decidim::Env.new("WEGLOT_API_KEY", "").to_s
        attribute :weglot_cache, Boolean, default: false

        expose_to_javascript :deepl_enabled, :minimalistic_deepl_enabled, :weglot_enabled, :weglot_cache
      end
    end
  end
end
