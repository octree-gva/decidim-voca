# frozen_string_literal: true

module Decidim
  module Voca
    module SyncLocales
      # Walks all Decidim ActiveRecord models and logs rows where LocaleContext resolution fails for any reason.
      class RelationLintRunner
        def call
          Rails.application.eager_load!
          log_path = Rails.root.join("tmp", "#{Date.current.strftime("%Y%m%d")}_relation_lint.log")
          FileUtils.mkdir_p(log_path.dirname)

          failures = 0
          File.open(log_path, "a") do |log|
            decidim_models.each do |model|
              model.unscoped.find_each do |record|
                LocaleContext.for(record)
              rescue StandardError => e
                failures += 1
                rid = record.respond_to?(:id) ? record.id : "n/a"
                log.puts("#{model.name}\t#{rid}\t#{e.class}: #{e.message}")
              end
            rescue StandardError => e
              failures += 1
              log.puts("#{model.name}\t-\t#{e.class}: #{e.message}")
            end
          end

          $stdout.puts "Relation lint complete: #{failures} failure(s) logged to #{log_path}"
          failures
        end

        private

        def decidim_models
          ActiveRecord::Base.descendants.select do |cls|
            next false if cls.name.blank?
            next false unless cls.name.start_with?("Decidim::")
            next false if cls.name.start_with?("Decidim::Dev::")
            next false if cls.name.start_with?("Decidim::System::")
            next false if cls.name.start_with?("Decidim::TermCustomizer::")
            next false if cls.abstract_class?
            next false unless cls.table_exists?

            true
          end.sort_by(&:name)
        end
      end
    end
  end
end
