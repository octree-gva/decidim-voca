# frozen_string_literal: true

require "json"

module Decidim
  module Voca
    module Snapshot
      class Lockfile
        def self.generate(lockfile_path)
          lockfile_data = {
            "decidim_modules" => extract_decidim_modules,
            "npm_lock" => extract_npm_packages(read_npm_lock)
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
          current_npm = extract_npm_packages(read_npm_lock)

          target_modules = normalize_hash(snapshot_data["decidim_modules"])
          current_modules = normalize_hash(current_modules)

          target_npm = normalize_hash(snapshot_data["npm_lock"]) || {}

          errors = []
          target_modules.each do |module_name, module_version|
            unless current_modules.key?(module_name)
              errors.push("Missing module #{module_name}, ~>#{module_version}")
              next
            end
            target_ver = version_from_module_hash(module_version)
            current_ver = version_from_module_hash(current_modules[module_name])
            next if target_ver.nil? || current_ver.nil?
            if Gem::Version.new(current_ver) != Gem::Version.new(target_ver)
              errors.push("Version mismatch for #{module_name}: lockfile #{target_ver}, current #{current_ver}")
            end
          end
          target_npm.each do |npm_name, target_ver|
            unless current_npm.key?(npm_name)
              errors.push("Missing npm package #{npm_name}, ~>#{target_ver}")
              next
            end
            current_ver = current_npm[npm_name].to_s
            next if target_ver.to_s.empty? || current_ver.empty?
            if Gem::Version.new(current_ver) != Gem::Version.new(target_ver.to_s)
              errors.push("Version mismatch for npm package #{npm_name}: lockfile #{target_ver}, current #{current_ver}")
            end
          end

          errors
        end

        def self.version_from_module_hash(h)
          return nil unless h.is_a?(Hash)
          v = h["version"] || h[:version]
          v.to_s if v
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

        # Parses package-lock.json (v2/v3). Uses only packages[""]["dependencies"];
        # file: deps are skipped. Resolved version taken from packages["node_modules/<name>"]
        # when present (so we never enumerate node_modules, only look up root deps).
        # @param content [String, nil] raw package-lock.json content
        # @return [Hash<String,String>]
        def self.extract_npm_packages(content)
          return {} if content.nil? || content.to_s.strip.empty?

          data = JSON.parse(content)
          packages = data["packages"]
          return {} unless packages.is_a?(Hash)

          root = packages[""]
          return {} unless root.is_a?(Hash)

          deps = root["dependencies"] || {}
          result = {}
          deps.each do |name, spec|
            spec = spec.to_s
            next if spec.start_with?("file:") || spec.empty?

            path = "node_modules/#{name}"
            resolved = packages[path].is_a?(Hash) && packages[path]["version"]
            # Use root spec when it's an exact version; else use resolved from node_modules
            result[name] = if Gem::Version.correct?(spec)
              spec
            elsif resolved
              packages[path]["version"].to_s
            else
              spec
            end
          end
          normalize_hash(result)
        end
      end
    end
  end
end
