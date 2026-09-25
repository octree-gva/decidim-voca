# frozen_string_literal: true

module Decidim
  module Voca
    module SyncLocales
      # Mutable counters for MT enqueue vs skip-already-translated.
      class EnqueueStats
        attr_reader :enqueued, :skipped_existing

        def initialize(enqueued: 0, skipped_existing: 0)
          @enqueued = enqueued
          @skipped_existing = skipped_existing
        end

        def add!(other)
          return self unless other

          @enqueued += other.enqueued
          @skipped_existing += other.skipped_existing
          self
        end

        def empty?
          enqueued.zero? && skipped_existing.zero?
        end

        def self.empty
          new
        end
      end
    end
  end
end
