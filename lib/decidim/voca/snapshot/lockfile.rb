# frozen_string_literal: true

require "json"
require "semantic_range"

module Decidim
  module Voca
    module Snapshot
      class Lockfile
        def self.validator(rails_root: Rails.root)
          Validator.new(rails_root:)
        end

        class Validator
          def initialize(rails_root: Rails.root)
            @rails_root = rails_root
          end

          def generate(lockfile_path)
            lockfile_data = {
              "decidim_modules" => extract_decidim_modules,
              "npm_lock" => extract_npm_packages(read_npm_lock)
            }

            File.write(lockfile_path, lockfile_data.to_json)
          end

          def validate(lockfile_path)
            errors(lockfile_path).any?
          end

          def validate!(lockfile_path)
            errs = errors(lockfile_path)
            raise errs.join("\n") if errs.any?
          end

          def errors(lockfile_path)
            return [] unless File.exist?(lockfile_path)

            snapshot_data = JSON.parse(File.read(lockfile_path))
            current_modules = extract_decidim_modules
            npm_lock_content = read_npm_lock
            current_npm = extract_npm_packages(npm_lock_content)

            target_modules = normalize_hash(snapshot_data["decidim_modules"])
            current_modules = normalize_hash(current_modules)

            target_npm = normalize_hash(snapshot_data["npm_lock"]) || {}

            errs = modules_errors(target_modules, current_modules)

            if target_npm.any? && npm_lock_content.nil?
              errs << "package-lock.json not found. Run `npm install` to generate it before restoring a snapshot."
              return errs
            end

            errs + npm_errors(target_npm, current_npm)
          rescue Errno::ENOENT
            []
          end

          def extract_decidim_modules
            modules = {}
            root_path = @rails_root.to_s

            gemfile_lock_path = File.join(root_path, "Gemfile.lock")
            if File.exist?(gemfile_lock_path)
              content = File.read(gemfile_lock_path)
              content.scan(/^\s+(decidim-[\w-]+) \(([\d.]+)\)/) do |match|
                module_name = match[0]
                version = match[1]
                modules[module_name] = { "version" => version }
              end
            end

            modules
          end

          def read_npm_lock
            npm_lock_path = @rails_root.join("package-lock.json")
            return nil unless File.exist?(npm_lock_path)

            File.read(npm_lock_path)
          end

          def extract_npm_packages(content)
            packages = package_lock_packages(content)
            root = package_lock_root(packages)
            return {} if root.nil?

            deps = root["dependencies"] || {}
            result = deps.each_with_object({}) do |(name, spec), acc|
              resolved = resolved_npm_dep_version(packages, name)
              version = npm_dependency_version(spec, resolved)
              next if version.nil?

              acc[name] = version
            end

            normalize_hash(result)
          end

          def normalize_hash(hash)
            return hash unless hash.is_a?(Hash)

            hash.transform_keys(&:to_s).transform_values do |v|
              v.is_a?(Hash) ? normalize_hash(v) : v
            end
          end

          private

          def modules_errors(target_modules, current_modules)
            target_modules.each_with_object([]) do |(module_name, module_version), errs|
              unless current_modules.has_key?(module_name)
                errs << "Missing module #{module_name}, ~>#{module_version}"
                next
              end

              target_ver = version_from_module_hash(module_version)
              current_ver = version_from_module_hash(current_modules[module_name])
              next if validate_gems_version(current_ver, target_ver)

              errs << "Version mismatch for #{module_name}: lockfile #{target_ver}, current #{current_ver}"
            end
          end

          def npm_errors(target_npm, current_npm)
            target_npm.each_with_object([]) do |(npm_name, target_ver), errs|
              unless current_npm.has_key?(npm_name)
                errs << "Missing npm package #{npm_name}, ~>#{target_ver}"
                next
              end

              current_ver = current_npm[npm_name].to_s
              next if validate_npm_version(current_ver, target_ver)

              errs << "Version mismatch for npm package #{npm_name}: lockfile #{target_ver}, current #{current_ver}"
            end
          end

          def validate_gems_version(current_ver, target_ver)
            current_ver = current_ver.to_s
            target_ver = target_ver.to_s

            return true if current_ver.empty? || target_ver.empty?

            Gem::Version.new(current_ver) == Gem::Version.new(target_ver)
          rescue ArgumentError
            current_ver == target_ver
          end

          def validate_npm_version(current_ver, target_ver)
            current_ver = current_ver.to_s
            target_ver = target_ver.to_s

            return true if current_ver.empty? || target_ver.empty?

            return SemanticRange.satisfies?(current_ver, target_ver) if target_ver.match?(/\A[~^<>=]/)

            validate_gems_version(current_ver, target_ver)
          rescue StandardError
            current_ver == target_ver
          end

          def version_from_module_hash(module_hash)
            return nil unless module_hash.is_a?(Hash)

            v = module_hash["version"] || module_hash[:version]
            return v.to_s if v

            nil
          end

          def package_lock_packages(content)
            return nil if content.nil? || content.to_s.strip.empty?

            data = JSON.parse(content)
            packages = data["packages"]
            return nil unless packages.is_a?(Hash)

            packages
          end

          def package_lock_root(packages)
            return nil unless packages.is_a?(Hash)

            root = packages[""]
            return nil unless root.is_a?(Hash)

            root
          end

          def resolved_npm_dep_version(packages, name)
            return nil unless packages.is_a?(Hash)

            dep = packages["node_modules/#{name}"]
            return dep["version"] if dep.is_a?(Hash)

            nil
          end

          def npm_dependency_version(spec, resolved)
            raw = npm_spec_string(spec)
            return nil if raw.empty? || raw.start_with?("file:")

            return raw if exact_semver?(raw)

            cleaned = raw.sub(/\A[~^=v]+/, "")
            resolved.to_s.empty? ? cleaned : resolved.to_s
          end

          def npm_spec_string(spec)
            return (spec["version"] || spec[:version]).to_s.strip if spec.is_a?(Hash)

            spec.to_s.strip
          end

          def exact_semver?(value)
            value.match?(/\A\d+(?:\.\d+){1,3}(?:[a-zA-Z0-9.+-]*)\z/)
          end
        end
      end
    end
  end
end
