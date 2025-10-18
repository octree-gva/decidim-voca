# frozen_string_literal: true

module Decidim
  module Voca
    module Overrides
      module AttachmentOverrides
        extend ActiveSupport::Concern

        included do
          alias_method :decidim_file_type, :file_type

          def file_type
            byebug
            return file.blob.filename.extension_without_delimiter if file? && file&.blob&.filename

            "link" if link?
          end
        end
      end
    end
  end
end
