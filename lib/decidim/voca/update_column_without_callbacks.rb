# frozen_string_literal: true

module Decidim
  module Voca
    # Writes JSONB/columns without validations or callbacks.
    # Required for nested machine-translation merges so after_save MT hooks do not re-enter.
    module UpdateColumnWithoutCallbacks
      module_function

      # rubocop:disable Rails/SkipsModelValidations
      def call(record, attribute, value)
        record.update_column(attribute, value)
      end

      def call_many(record, attributes)
        record.update_columns(attributes)
      end
      # rubocop:enable Rails/SkipsModelValidations
    end
  end
end
