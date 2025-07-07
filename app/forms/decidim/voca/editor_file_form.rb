# frozen_string_literal: true

module Decidim
  module Voca
    class EditorFileForm < ::Decidim::Form
      mimic :editor_file

      attribute :file
      attribute :author_id, Integer
      attribute :path, String

      validates :author_id, presence: true
      validates :file, presence: true

      alias organization current_organization
    end
  end
end
