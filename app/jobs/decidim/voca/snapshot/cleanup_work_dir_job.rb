# frozen_string_literal: true

module Decidim
  module Voca
    module Snapshot
      class CleanupWorkDirJob < ::Decidim::ApplicationJob
        queue_as :default

        def perform(work_dir_path)
          return unless work_dir_path

          work_dir = Pathname.new(work_dir_path)
          return unless work_dir.exist?

          FileUtils.rm_rf(work_dir)
        end
      end
    end
  end
end
