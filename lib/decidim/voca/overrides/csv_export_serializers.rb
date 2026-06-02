# frozen_string_literal: true

module Decidim
  module Voca
    module Overrides
      # Prepends voca multi-locale CSV export behaviour on Decidim serializers.
      module ProposalSerializerCsvExport
        module_function

        def apply
          mod = Decidim::Voca::Export::ProposalSerializerLocalizedCsv
          return if Decidim::Proposals::ProposalSerializer.ancestors.include?(mod)

          Decidim::Proposals::ProposalSerializer.prepend(mod)
        end
      end

      module CommentSerializerOverride
        module_function

        def apply
          mod = Decidim::Voca::Export::CommentSerializerLocalizedCsv
          return if Decidim::Comments::CommentSerializer.ancestors.include?(mod)

          Decidim::Comments::CommentSerializer.prepend(mod)
        end
      end

      module UserAnswersSerializerOverride
        module_function

        def apply
          mod = Decidim::Voca::Export::UserAnswersSerializerLocalizedCsv
          return if Decidim::Forms::UserAnswersSerializer.ancestors.include?(mod)

          Decidim::Forms::UserAnswersSerializer.prepend(mod)
        end
      end

      module CsvExportSerializers
        module_function

        def apply
          ProposalSerializerCsvExport.apply
          CommentSerializerOverride.apply
          UserAnswersSerializerOverride.apply
        end
      end
    end
  end
end
