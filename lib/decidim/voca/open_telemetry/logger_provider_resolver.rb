# frozen_string_literal: true

module Decidim
  module Voca
    module OpenTelemetry
      module LoggerProviderResolver
        module_function

        def current
          Decidim::Voca.opentelemetry_logger_provider
        end
      end
    end
  end
end
