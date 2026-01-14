# frozen_string_literal: true

$LOAD_PATH.push File.expand_path("lib", __dir__)

require "decidim/voca/version"

Gem::Specification.new do |s|
  s.version = Decidim::Voca.version
  s.authors = ["Hadrien Froger", "Renato Silva"]
  s.email = ["hadrien@octree.ch", "renato@octree.ch"]
  s.license = "AGPL-3.0"
  s.homepage = "https://git.octree.ch/decidim/vocacity/decidim-modules/decidim-voca"
  s.required_ruby_version = ">= 3.2.2"

  s.name = "decidim-voca"
  s.summary = "A decidim voca module"
  s.description = "Small fixes and improvements for Decidim distributed by voca.city."

  s.files = Dir["{app,config,lib,bin}/**/*", "LICENSE.md", "Rakefile", "README.md"]

  s.executables = ["vocasnap"]
  s.require_paths = ["lib"]
  s.add_dependency "decidim-admin", Decidim::Voca.decidim_version
  s.add_dependency "decidim-decidim_awesome", Decidim::Voca.compat_decidim_awesome_version
  s.add_dependency "decidim-ephemeral_participation", "~> 0.0.6"
  s.add_dependency "decidim-telemetry", "~> 0.0.3"
  s.add_dependency "decidim-user_fields", "~> 0.1.4"

  s.add_dependency "deepl-rb", "~> 3.2.0"
  s.add_dependency "deface", "~> 1.9"
  s.add_dependency "faker", "~> 3.5.1"
  s.add_dependency "good_job", "~> 4.5.1"

  s.add_dependency "image_processing", "~> 1.2"
  s.add_dependency "next_gen_images", "~> 1.1.1"
  s.add_dependency "ruby-vips", "~> 2.2.4"
  s.add_dependency "thor", "~> 1.0"
  s.metadata["rubygems_mfa_required"] = "true"
end
