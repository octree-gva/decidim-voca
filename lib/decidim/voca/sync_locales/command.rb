# frozen_string_literal: true

module Decidim
  module Voca
    module SyncLocales
      # Invokes decidim:locales:rebuild_search, runs locale normalization over all translatable rows, then rebuilds search again.
      class Command < Decidim::Command
        def call
          ensure_minimalistic_deepl!
          ensure_rake_tasks!
          rebuild_search_task.reenable
          rebuild_search_task.invoke
          Rails.logger.debug "=" * 80
          Rails.logger.debug "Starting sync locales"
          Runner.new.call
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

      def self.call
        Command.call
      end
    end
  end
end
