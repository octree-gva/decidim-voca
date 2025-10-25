# frozen_string_literal: true

module Decidim
  # This holds the decidim-meetings version.
  module Voca
    def self.version
      "0.0.12" # DO NOT UPDATE MANUALLY
    end

    def self.decidim_version
      [">= 0.29", "<0.30"].freeze
    end

    def self.compat_decidim_awesome_version
      "~> 0.12.5"
    end
    def self.compat_decidim_telemetry_version
      "v0.0.3" # check decidim-voca.gemspec to know wich version is compatible with your installs
    end
  end
end
