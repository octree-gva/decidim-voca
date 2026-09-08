# frozen_string_literal: true

module Decidim
  module Voca
    class Configuration
      class << self
        def config = self

        def configure
          yield self
        end
      end

      mattr_accessor :enable_minimalistic_deepl, default: true

      mattr_accessor :enable_weglot, default: ::Decidim::Env.new("WEGLOT_API_KEY", "").present?

      mattr_accessor :enable_next_gen_images, default: true

      mattr_accessor :weglot_api_key, default: ::Decidim::Env.new("WEGLOT_API_KEY", "").to_s

      mattr_accessor :enable_weglot_cache, default: false
    end
  end
end
