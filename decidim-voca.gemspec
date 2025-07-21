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

  s.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end

  s.bindir = "exe"
  s.executables = s.files.grep(%r{^exe/}) { |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency "decidim-admin", Decidim::Voca.decidim_version
  s.add_dependency "decidim-decidim_awesome", "~> 0.12.0"
  s.add_dependency "deface", "~> 1.9"
  s.add_dependency "faker", "~> 3.5.1"
  s.add_dependency "image_processing", "~> 1.2"
  s.add_dependency "next_gen_images", "~> 1.1.1"
  s.add_dependency "ruby-vips", "~> 2.2.4"
  s.add_dependency "tty-prompt", "~> 0.23.1"
  s.add_dependency "tty-table", "~> 0.12.0"
  s.metadata["rubygems_mfa_required"] = "true"
end
