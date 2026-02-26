# frozen_string_literal: true

require "json"

module Decidim
  module Voca
    module Snapshot
      class Lockfile
        def self.generate(lockfile_path)
          lockfile_data = {
            "decidim_modules" => extract_decidim_modules,
            "npm_lock" => read_npm_lock
          }

          File.write(lockfile_path, lockfile_data.to_json)
        end

        def self.validate(lockfile_path)
          self.errors(lockfile_path).any?
        end
        def self.validate!(lockfile_path)
          errors = self.errors(lockfile_path)
          raise errors.join("\n") if errors.any?
        end

        def self.errors(lockfile_path)
          return [] unless File.exist?(lockfile_path)

          snapshot_data = JSON.parse(File.read(lockfile_path))
          current_modules = extract_decidim_modules
          current_npm = read_npm_lock

          target_modules = normalize_hash(snapshot_data["decidim_modules"]) 
          current_modules = normalize_hash(current_modules) 
          
          target_npm = normalize_hash(snapshot_data["npm_lock"])

          errors = []
          # Add in error all modules that are in target_modules but not in current_modules
          target_modules.each do |module_name, module_version|
            unless current_modules.key?(module_name)
              errors.push("Missing module #{module_name}, ~>#{module_version}")
            end
          end
          target_npm.each do |npm_name, npm_version|
            unless current_npm.key?(npm_name)
              errors.push("Missing npm package #{npm_name}, ~>#{npm_version}")
            end
          end
          
          errors
        end

        def self.normalize_hash(hash)
          return hash unless hash.is_a?(Hash)

          hash.transform_keys(&:to_s).transform_values do |v|
            v.is_a?(Hash) ? normalize_hash(v) : v
          end
        end

        def self.extract_decidim_modules
          modules = {}
          root_path = Rails.root.to_s

          # Check Gemfile.lock for decidim modules
          gemfile_lock_path = File.join(root_path, "Gemfile.lock")
          if File.exist?(gemfile_lock_path)
            content = File.read(gemfile_lock_path)
            content.scan(/^\s+(decidim-[\w-]+) \(([\d.]+)\)/) do |match|
              module_name = match[0]
              version = match[1]
              modules[module_name] = {
                "version" => version
              }
            end
          end
          modules
        end

        def self.read_npm_lock
          root_path = Rails.root
          npm_lock_path = root_path.join("package-lock.json")
          unless File.exist?(npm_lock_path)
            system("npm install", chdir: root_path.to_s)
            return nil unless File.exist?(npm_lock_path)
          end

          File.read(npm_lock_path)
        end
      end
    end
  end
end
