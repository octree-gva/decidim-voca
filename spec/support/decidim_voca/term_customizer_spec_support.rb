# frozen_string_literal: true

# Minimal TermCustomizer schema + models for specs (gem is not a decidim-voca dependency).
module DecidimVocaTermCustomizerSpecSupport
  module_function

  def ensure_tables!
    return if ActiveRecord::Base.connection.table_exists?(:decidim_term_customizer_translations)

    ActiveRecord::Schema.define do
      create_table :decidim_term_customizer_translation_sets do |t|
        t.jsonb :name
      end

      create_table :decidim_term_customizer_translations do |t|
        t.string :locale
        t.string :key
        t.text :value
        t.references :translation_set, null: false, index: { name: "voca_tc_translation_set_idx" }
      end

      create_table :decidim_term_customizer_constraints do |t|
        t.references :decidim_organization, null: false, index: { name: "voca_tc_constraint_org_idx" }
        t.references :subject, polymorphic: true, index: { name: "voca_tc_constraint_subject_idx" }
        t.references :translation_set, null: false, index: { name: "voca_tc_constraint_set_idx" }
      end
    end
  end

  def ensure_models!
    ensure_tables!
    return if defined?(::Decidim::TermCustomizer::Translation)

    ::Decidim.const_set(:TermCustomizer, Module.new) unless ::Decidim.const_defined?(:TermCustomizer)

    unless ::Decidim::TermCustomizer.const_defined?(:TranslationSet)
      base = defined?(::ApplicationRecord) ? ::ApplicationRecord : ::ActiveRecord::Base
      translation_set = Class.new(base) do
        self.table_name = "decidim_term_customizer_translation_sets"

        has_many :translations,
                 class_name: "Decidim::TermCustomizer::Translation",
                 dependent: :destroy,
                 inverse_of: :translation_set
        has_many :constraints,
                 class_name: "Decidim::TermCustomizer::Constraint",
                 dependent: :destroy,
                 inverse_of: :translation_set
      end
      ::Decidim::TermCustomizer.const_set(:TranslationSet, translation_set)
    end

    unless ::Decidim::TermCustomizer.const_defined?(:Translation)
      base = defined?(::ApplicationRecord) ? ::ApplicationRecord : ::ActiveRecord::Base
      translation = Class.new(base) do
        self.table_name = "decidim_term_customizer_translations"

        belongs_to :translation_set, class_name: "Decidim::TermCustomizer::TranslationSet"
      end
      ::Decidim::TermCustomizer.const_set(:Translation, translation)
    end

    return if ::Decidim::TermCustomizer.const_defined?(:Constraint)

    base = defined?(::ApplicationRecord) ? ::ApplicationRecord : ::ActiveRecord::Base
    constraint = Class.new(base) do
      self.table_name = "decidim_term_customizer_constraints"

      belongs_to :organization, foreign_key: :decidim_organization_id, class_name: "Decidim::Organization"
      belongs_to :translation_set, class_name: "Decidim::TermCustomizer::TranslationSet"
    end
    ::Decidim::TermCustomizer.const_set(:Constraint, constraint)
  end
end
