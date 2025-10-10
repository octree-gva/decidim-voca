# frozen_string_literal: true

module Decidim
  # This holds the decidim-meetings version.
  module Voca
    def self.version
      "0.0.11" # DO NOT UPDATE MANUALLY
    end

    def self.decidim_version
      [">= 0.29", "<0.30"].freeze
    end
  end
end
