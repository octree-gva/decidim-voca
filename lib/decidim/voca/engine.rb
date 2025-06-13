# frozen_string_literal: true

require "rails"
require "decidim/core"
require "deface"
require "next_gen_images"

module Decidim
  module Voca
    # This is the engine that runs on the public interface of voca.
    class Engine < ::Rails::Engine
      isolate_namespace Decidim::Voca

      routes do
        get "/_/csrf/refresh", to: "http_cache/refresh#show"
      end

      # Enforce profile verification
      config.to_prepare do
        # Decidim::AccountForm will use these regexps:
        Decidim::UserBaseEntity::REGEXP_NAME = /\A(?!.*[<>?%&\^*#@()\[\]=+:;"{}\\|])/m
        Decidim::User::REGEXP_NICKNAME = /\A[\w-]+\z/m
        # If it has gone through forms, and still want to save, we sanitize on save:
        Decidim::UserBaseEntity.include(Decidim::Voca::Overrides::UserProfileVerificationOverride)
      end

      # Setup upload variants
      config.to_prepare do
        upload_variants = {
          thumbnail: { resize_to_fit: [nil, 237] },
          big: { resize_to_limit: [nil, 1000] },
          thumbnail_webp: { resize_to_fit: [nil, 237], convert: :webp, format: :webp, saver: { subsample_mode: "on", strip: true, interlace: true, quality: 80 } },
          big_webp: { resize_to_limit: [nil, 1000], convert: :webp, format: :webp, saver: { subsample_mode: "on", strip: true, interlace: true, quality: 80 } }
        }
        # Includes overrides
        ActionView::Helpers::AssetTagHelper.include(Decidim::Voca::Overrides::ImageTagOverrides)
        Decidim::ViewModel.include Decidim::Voca::Overrides::DecidimViewModel

        # Participatory Process Banner Image
        Decidim::ParticipatoryProcess.include(Decidim::Voca::Overrides.override_for_has_one_attached(:hero_image, Decidim::HeroImageUploader))
        Decidim::ParticipatoryProcesses::ProcessGCell.include(Decidim::Voca::Overrides.override_cell_resource_image_url(:hero_image))

        # Assemblies
        Decidim::Assembly.include(Decidim::Voca::Overrides.override_for_has_one_attached(:hero_image, Decidim::HeroImageUploader))
        Decidim::Assemblies::AssemblyGCell.include(Decidim::Voca::Overrides.override_cell_resource_image_url(:hero_image))

        # Proposals
        Decidim::Proposals::ProposalGCell.include(Decidim::Voca::Overrides::ProposalGCellOverride)
        Decidim::AttachmentUploader.set_variants { upload_variants }
      end

      initializer "decidim_voca.webpacker.assets_path" do
        Decidim.register_assets_path File.expand_path("#{Decidim::Voca::Engine.root}/app/packs")
      end

      initializer "decidim_voca.image_processing" do
        Rails.application.configure do
          config.active_storage.variant_processor = :vips
        end
      end

      initializer "decidim_voca.http_cache" do
        # Insert the middleware only if cache is enabled
        Rails.application.configure do
          if config.cache_store != :null_store
            config.middleware.insert_after ::Warden::Manager, Decidim::Voca::HttpCache::Middleware
          end
        end
      end

      initializer "decidim_voca.routes" do
        Decidim::Core::Engine.routes do
          mount Decidim::Voca::Engine, at: "/", as: "decidim_voca"
        end
      end
    end
  end
end
