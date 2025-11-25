# frozen_string_literal: true

require "decidim/gem_manager"
namespace :decidim do
namespace :voca do
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
      decidim_voca_dependencies.each do |type, packages|
        puts "install NPM packages. You can also do this manually with this command:"
        puts "npm i --save-#{type} #{packages.join(" ")}"
        voca_system! "npm i --save-#{type} #{packages.join(" ")}"
      end
    end

    def decidim_voca_dependencies
      @decidim_voca_dependencies ||= begin
        package_json = JSON.parse(File.read(decidim_voca.join("package.json")))

        {
          prod: package_json["dependencies"].map { |package, version| "#{package}@#{version}" }
          # dev: package_json["devDependencies"].map { |package, version| "#{package}@#{version}" }
        }.freeze
      end
    end

    def decidim_voca
      @decidim_voca ||= Pathname.new(decidim_voca_gemspec.full_gem_path) if Gem.loaded_specs.has_key?(voca_gem_name)
    end

    def decidim_voca_gemspec
      @decidim_voca_gemspec ||= Gem.loaded_specs[voca_gem_name]
    end

    def rails_app_path
      @rails_app_path ||= Rails.root
    end

    def copy_voca_file_to_application(origin_path, destination_path = origin_path)
      FileUtils.cp(decidim_voca_path.join(origin_path), rails_app_path.join(destination_path))
    end

    def voca_system!(command)
      system("cd #{rails_app_path} && #{command}") || abort("\n== Command #{command} failed ==")
    end

    def voca_gem_name
      "decidim-voca"
    end
  end
end
end