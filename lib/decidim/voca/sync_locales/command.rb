# frozen_string_literal: true

module Decidim
  module Voca
    module SyncLocales
      # Runs locale normalization over all translatable rows, then invokes decidim:locales:rebuild_search.
      class Command < Decidim::Command
        def self.call(model_name: nil)
          new(model_name:).call
        end

        def initialize(model_name: nil)
          @model_name = model_name
        end

        def call
          ensure_minimalistic_deepl!
          if term_customizer_only?
            Rails.logger.debug "Starting TermCustomizer sync locales (no search rebuild)"
            Runner.new(model_name: @model_name).call
            Rails.logger.debug "TermCustomizer sync locales completed"
            broadcast(:ok)
            return
          end

          ensure_rake_tasks!
          Rails.logger.debug "=" * 80
          Rails.logger.debug "Starting sync locales"
          Runner.new(model_name: @model_name).call
          Rails.logger.debug "Sync locales completed"
          Rails.logger.debug "=" * 80
          rebuild_search_task.reenable
          rebuild_search_task.invoke
          broadcast(:ok)
        rescue StandardError => e
          broadcast(:invalid, e.message)
          raise
        end

        private

        def term_customizer_only?
          @model_name.to_s == TermCustomizerSync::MODEL_NAME
        end

        def ensure_minimalistic_deepl!
          return if Decidim::Voca.minimalistic_deepl?

          raise(StandardError, "Decidim::Voca.minimalistic_deepl? must be true to run #{self.class.name}")
        end

        def ensure_rake_tasks!
          return if Rake::Task.task_defined?("decidim:locales:rebuild_search")

          Rails.application.load_tasks
        end

        def rebuild_search_task
          @rebuild_search_task ||= Rake::Task["decidim:locales:rebuild_search"]
        end
      end

      def self.call(model_name: nil)
        Command.call(model_name:)
      end

      def self.translatable_model_names
        Rails.application.eager_load!
        Lister.new.names
      end

      # Public listing helper for rake + validation.
      class Lister
        include TranslatableModels

        def names
          names = translatable_model_names
          names << TermCustomizerSync::MODEL_NAME if TermCustomizerSync.available?
          names << ContentBlockSettingSync::MODEL_NAME if defined?(Decidim::ContentBlock)
          names.uniq.sort
        end
      end
    end
  end
end
