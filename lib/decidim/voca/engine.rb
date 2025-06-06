# frozen_string_literal: true

require "rails"
require "decidim/core"
require "deface"

module Decidim
  module Voca
    # This is the engine that runs on the public interface of voca.
    class Engine < ::Rails::Engine
      isolate_namespace Decidim::Voca

      config.to_prepare do
        # Includes overrides

      end

      # Register a new path for assets
      initializer "decidim_voca.webpacker.assets_path" do
        Decidim.register_assets_path File.expand_path("#{Decidim::Voca::Engine.root}/app/packs")
      end

    end
  end
end
