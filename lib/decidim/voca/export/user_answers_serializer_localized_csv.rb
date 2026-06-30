# frozen_string_literal: true

module Decidim
  module Voca
    module Export
      # Prepended on UserAnswersSerializer: +locale/q_<id>+ columns.
      #
      # Decidim does not persist the UI locale used when submitting +Decidim::Forms::Answer+
      # (see +Decidim::Forms::AnswerQuestionnaire+). The export +locale+ column uses the
      # organization default as a neutral placeholder.
      module UserAnswersSerializerLocalizedCsv
        def serialize
          data = super
          serialize_localized_data(data)
        end

        private

        def serialize_localized_data(data)
          questionnaire = answers&.first&.questionnaire
          return data unless questionnaire

          org = questionnaire.questionnaire_for.try(:organization)
          return data unless org

          locales = Array(org.available_locales).map(&:to_s).uniq.compact_blank
          return data if locales.empty?

          nested = build_answer_columns(questionnaire, answers, locales)
          question_keys = data.keys.select { |k| k.to_s.match?(/\A\d+\.\s/) }
          non_question_fields = data.except(*question_keys)
          locale_prefixed_columns = nested.deep_stringify_keys
          submission_locale = org.default_locale.to_s
          non_question_fields.merge(locale_prefixed_columns).merge(locale: submission_locale)
        end

        def build_answer_columns(questionnaire, answers, locales)
          questions = Decidim::Forms::Question.where(decidim_questionnaire_id: questionnaire.id).order(:position)
          nested = {}
          locales.each { |loc| nested[loc] = {} }

          questions.each do |question|
            answer = answers.find { |a| a.decidim_question_id == question.id }
            val = answer ? normalize_body(answer) : ""
            locales.each do |loc|
              nested[loc]["q_#{question.id}"] = val
            end
          end
          nested
        end
      end
    end
  end
end
