# frozen_string_literal: true

require_relative "deepl/deepl_active_job_context"
require_relative "deepl/deepl_context"
require_relative "deepl/deepl_form_builder_overrides"
require_relative "deepl/deepl_machine_translator"
require_relative "deepl/deepl_middleware"
require_relative "deepl/translation_bar_overrides"
require_relative "deepl/engine_config"

# Compatibility shim: older code referenced +Decidim::Voca::Deepl+.
module Decidim
  module Voca
    DeeplContext = DeepL::Context unless const_defined?(:DeeplContext)
    DeeplMiddleware = DeepL::Middleware unless const_defined?(:DeeplMiddleware)
    DeeplMachineTranslator = DeepL::MachineTranslator unless const_defined?(:DeeplMachineTranslator)
    DeeplActiveJobContext = DeepL::ActiveJobContext unless const_defined?(:DeeplActiveJobContext)
    DeeplFormBuilderOverrides = DeepL::DeepLFormBuilderOverrides unless const_defined?(:DeeplFormBuilderOverrides)

    module Deepl
      def self.const_missing(name)
        return Decidim::Voca::DeepL.const_get(name) if Decidim::Voca.const_defined?(:DeepL)

        super
      end
    end
  end
end

