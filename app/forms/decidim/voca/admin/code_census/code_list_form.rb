# frozen_string_literal: true

module Decidim
  module Voca
    module Admin
      module CodeCensus
        class CodeListForm < Form
          mimic :code_list

          attribute :codes_text, String

          validates :codes_text, presence: true

          def codes
            codes_text.to_s.split(/\r?\n/).map(&:strip).compact_blank.uniq
          end
        end
      end
    end
  end
end
