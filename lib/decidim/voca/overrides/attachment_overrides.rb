# frozen_string_literal: true

module Decidim
  module Voca
    module Overrides
      module AttachmentOverrides
        extend ActiveSupport::Concern

        included do
          alias_method :decidim_file_type, :file_type

          def file_type
            return file.blob.filename.extension_without_delimiter if file?

            "link" if link?
          end
        end
      end
    end
  end
end
