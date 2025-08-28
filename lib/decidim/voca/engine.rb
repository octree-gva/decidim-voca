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
        Decidim::Core::Engine.routes.draw do
          post :editor_files, to: "voca/editor_files#create"
          post :locate, to: "voca/geolocation#locate"
          if Rails.application.config.active_job.queue_adapter == :good_job
            authenticate :admin, ->(admin) { !admin.locked_at? } do
              mount GoodJob::Engine => "/system/active_jobs"
            end
          end
        end
      end

      # Enforce profile verification
      config.to_prepare do
        # Decidim::AccountForm will use these regexps:
        Decidim::UserBaseEntity::REGEXP_NAME = /\A(?!.*[<>?%&\^*#@()\[\]=+:;"{}\\|])/m
        Decidim::User::REGEXP_NICKNAME = /\A[\w-]+\z/m
        # If it has gone through forms, and still want to save, we sanitize on save:
        Decidim::UserBaseEntity.include(Decidim::Voca::Overrides::UserProfileVerificationOverride)
      end

      # Fixes for geolocated proposals at creation
      config.to_prepare do
        Decidim::Proposals::CreateProposal.include(Decidim::Voca::Overrides::CreateProposalOverrides)
        Decidim::Map::Autocomplete::Builder.include(Decidim::Voca::Overrides::MapAutocompleteBuilderOverrides)
      end

      # Setup upload variants
      config.to_prepare do
        upload_variants = {
          thumbnail: { resize_to_fit: [nil, 237] },
          big: { resize_to_limit: [nil, 1000] },
          thumbnail_webp: { resize_to_fit: [nil, 237], convert: :webp, format: :webp, saver: { subsample_mode: "on", strip: true, interlace: true, quality: 100 } },
          big_webp: { resize_to_limit: [nil, 1000], convert: :webp, format: :webp, saver: { subsample_mode: "on", strip: true, interlace: true, quality: 100 } }
        }
        ActiveSupport.on_load(:action_view) { include NextGenImages::ViewHelpers }
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

        # Meetings
        Decidim::Meetings::Admin::MeetingsController.include(Decidim::Voca::Overrides::MeetingsControllerOverrides)

        # Etherpad
        Decidim::Etherpad::Pad.include(Decidim::Voca::Overrides::EtherpadOverrides)

        # User Group Form
        Decidim::UserGroupForm.include(Decidim::Voca::Overrides::UserGroupFormOverrides)

        # Footer topic "Help" hardcoded string
        Decidim::FooterTopicsCell.include(Decidim::Voca::Overrides::Footer::FooterTopicCellOverrides)
        Decidim::FooterMenuPresenter.include(Decidim::Voca::Overrides::Footer::FooterMenuPresenter)
      end

      # Decidim Awesome Proposal Override
      initializer "decidim.voca.after_awesome", after: "decidim_decidim_awesome.overrides" do
        config.to_prepare do
          Decidim::Proposals::ProposalSerializer.include(
            Decidim::Voca::Overrides::ProposalSerializerOverrides
          )
        end
      end

      initializer "decidim.voca.good_job", after: :load_config_initializers do
        # Execution mode is configurable, to adapt on demand:
        # - async_server: when your installation is small and want to run all in same server (but a new thread)
        # - external: when you run your own process with ``
        execution_mode = ENV.fetch("VOCA_ACTIVE_JOB_EXECUTION_MODE", "async_server").to_sym
        good_job_max_threads = ENV.fetch("VOCA_GOOD_JOB_MAX_THREADS", 5).to_i
        good_job_poll_interval = ENV.fetch("VOCA_GOOD_JOB_POLL_INTERVAL", 30).to_i
        good_job_shutdown_timeout = ENV.fetch("VOCA_GOOD_JOB_SHUTDOWN_TIMEOUT", 120).to_i
        good_job_queues = ENV.fetch("VOCA_GOOD_JOB_QUEUES", "*")
        supported_execution_modes = [:async_server, :external]
        unless supported_execution_modes.include?(execution_mode)
          raise "Unsupported execution mode: #{execution_mode}. Supported modes are: #{supported_execution_modes.join(", ")}"
        end

        Rails.application.configure do
          if config.active_job.queue_adapter == :good_job
            Rails.logger.warn("Overriding good_job configuration for Decidim")
            config.good_job.preserve_job_records = true
            config.good_job.retry_on_unhandled_error = true # To behave like sidekiq
            config.good_job.on_thread_error = ->(exception) { Rails.error.report(exception) }
            config.good_job.execution_mode = execution_mode
            config.good_job.queues = good_job_queues
            config.good_job.max_threads = good_job_max_threads
            config.good_job.poll_interval = good_job_poll_interval # seconds
            config.good_job.shutdown_timeout = good_job_shutdown_timeout # seconds
            config.good_job.enable_cron = false
            config.good_job.dashboard_default_locale = :en
          end
        end
      end

      initializer "decidim.voca.weglot", after: :load_config_initializers do
        # configure additional CSP for weglot
        if ::Decidim::Voca.weglot?
          Decidim.configure do |decidim_config|
            decidim_config.content_security_policies_extra["connect-src"] = [] unless decidim_config.content_security_policies_extra.has_key? "connect-src"
            decidim_config.content_security_policies_extra["connect-src"].push("*.weglot.com")

            decidim_config.content_security_policies_extra["script-src"] = [] unless decidim_config.content_security_policies_extra.has_key? "script-src"
            decidim_config.content_security_policies_extra["script-src"].push("*.weglot.com")
            decidim_config.content_security_policies_extra["script-src"].push("'unsafe-inline'")
          end
        end
      end

      initializer "decidim.voca.map_configuration", after: :load_config_initializers do
        Decidim.configure do |decidim_config|
          Rails.logger.warn("Decidim.config.maps will be overridden by voca maps configuration") unless decidim_config.maps

          # Setup CSP for geocoding, static maps (pngs), dynamic maps (tiles) and autocomplete.
          decidim_config.content_security_policies_extra = {} unless decidim_config.content_security_policies_extra
          decidim_config.content_security_policies_extra["connect-src"] = [] unless decidim_config.content_security_policies_extra.has_key? "connect-src"
          decidim_config.content_security_policies_extra["img-src"] = [] unless decidim_config.content_security_policies_extra.has_key? "img-src"

          decidim_config.content_security_policies_extra["connect-src"].push("*.hereapi.com", "*.openstreetmap.org", "photon.komoot.io", "*.basemaps.cartocdn.com",
                                                                             "*.maps.ls.hereapi.com")
          decidim_config.content_security_policies_extra["img-src"].push("*.hereapi.com", "*.openstreetmap.org", "photon.komoot.io", "*.basemaps.cartocdn.com",
                                                                         "*.maps.ls.hereapi.com")

          decidim_config.maps = {
            provider: :osm,
            api_key: ENV.fetch("MAPS_API_KEY", ""),
            dynamic: {
              tile_layer: {
                url: "https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png",
                api_key: false,
                attribution: %(
                          <a href="https://www.openstreetmap.org/copyright" target="_blank">&copy; OpenStreetMap</a> contributors
                        ).strip
              }
            },

            static: { url: "https://image.maps.ls.hereapi.com/mia/1.6/mapview" },
            autocomplete: {
              address_format: [%w(street houseNumber), "city", "country"],
              url: "https://photon.komoot.io/api/"
            },
            geocoding: { host: "nominatim.openstreetmap.org", use_https: true }
          }
        end
      end

      initializer "decidim_voca.webpacker.assets_path" do
        Decidim.register_assets_path File.expand_path("#{Decidim::Voca::Engine.root}/app/packs")
      end

      initializer "decidim_voca.cells" do
        Cell::ViewModel.view_paths << File.expand_path("#{Decidim::Voca::Engine.root}/app/cells")
      end

      initializer "decidim_voca.icons" do
        Decidim.icons.register(name: "camera", icon: "camera-line", category: "system", description: "", engine: :core)
      end
      initializer "decidim_voca.image_processing" do
        Rails.application.configure do
          config.active_storage.variant_processor = :vips
        end
      end
    end
  end
end
