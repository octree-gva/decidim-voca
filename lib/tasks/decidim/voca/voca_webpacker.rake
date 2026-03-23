# frozen_string_literal: true

require "decidim/gem_manager"

namespace :decidim_voca do
  namespace :webpacker do
    desc "Installs Voca webpacker files in Rails instance application"
    task install: :environment do
      raise "Decidim gem is not installed" if decidim_path.nil?

      install_voca_npm
    end

    desc "Adds Voca dependencies in package.json"
    task upgrade: :environment do
      raise "Decidim gem is not installed" if decidim_path.nil?

      install_voca_npm
    end

    def install_voca_npm
      return if voca_npm_dependencies.empty?

      puts "install NPM packages. You can also do this manually with this command:"
      puts "npm i #{voca_npm_dependencies.join(" ")}"
      voca_system! "npm i #{voca_npm_dependencies.join(" ")}"
    end

    def voca_npm_dependencies
      @voca_npm_dependencies ||= begin
        return [] if voca_path.nil? || !File.exist?(voca_path.join("package.json"))

        package_json = JSON.parse(File.read(voca_path.join("package.json")))

        (package_json["dependencies"] || {}).map { |package, version| "#{package}@#{version}" }
      end
    end

    def voca_path
      @voca_path ||= Pathname.new(voca_gemspec.full_gem_path) if Gem.loaded_specs.has_key?(voca_gem_name)
    end

    def rails_app_path
      @rails_app_path ||= Rails.root
    end

    def voca_system!(command)
      system("cd #{rails_app_path} && #{command}") || abort("\n== Command #{command} failed ==")
    end

    def voca_gemspec
      @voca_gemspec ||= Gem.loaded_specs[voca_gem_name]
    end

    def voca_gem_name
      "decidim-voca"
    end
  end
end
