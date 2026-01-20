# frozen_string_literal: true

require "English"
require "open3"

module Decidim
  module Voca
    module Snapshot
      class PrerequisitesChecker
        def check!
          check_psql_available!
          check_postgresql_version_compatibility!
          check_database_permissions!
        end

        def check_binaries!(binaries)
          missing = []
          binaries.each do |binary|
            missing << binary unless system("which", binary, out: File::NULL, err: File::NULL)
          end

          return if missing.empty?

          hints = installation_hints(missing)
          raise("Missing required binaries: #{missing.join(", ")}\n\n#{hints}")
        end

        def check_pg_dump_version_compatibility!
          server_version = postgresql_server_version
          client_version = pg_dump_version

          return unless server_version && client_version

          return if client_version >= server_version

          server_major_int = server_version.split(".").first.to_i
          hints = upgrade_pg_dump_hint(server_major_int)
          raise("Version mismatch: pg_dump #{client_version} is older than PostgreSQL server #{server_version}. " \
                "Upgrade pg_dump to match or exceed server version.\n\n#{hints}")
        end

        def installation_hints(missing_binaries)
          os_info = detect_os
          hints = []

          missing_binaries.each do |binary|
            case binary
            when "pg_dump"
              hints << install_pg_dump_hint(os_info)
            when "psql"
              hints << install_psql_hint(os_info)
            when "tar"
              hints << install_tar_hint(os_info)
            end
          end

          hints.join("\n")
        end

        # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
        def install_pg_dump_hint(os_info)
          server_version = postgresql_server_version
          server_major_int = server_version&.split(".")&.first&.to_i

          case os_info[:type]
          when :debian
            if server_major_int
              # rubocop:disable Layout/LineLength
              "Install pg_dump at PostgreSQL #{server_version}:\n  " \
                "curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /usr/share/keyrings/postgresql.gpg\n  " \
                "echo \"deb [signed-by=/usr/share/keyrings/postgresql.gpg] http://apt.postgresql.org/pub/repos/apt $(grep VERSION_CODENAME /etc/os-release | cut -d= -f2 | tr -d '\"')-pgdg main\" | tee /etc/apt/sources.list.d/pgdg.list\n  " \
                "apt-get update && apt-get install -y postgresql-client-#{server_major_int}"
              # rubocop:enable Layout/LineLength
            else
              "Install pg_dump: apt-get update && apt-get install -y postgresql-client"
            end
          when :fedora
            if server_major_int
              "Install pg_dump at PostgreSQL #{server_version}: dnf install -y postgresql#{server_major_int}"
            else
              "Install pg_dump: dnf install -y postgresql"
            end
          when :rhel
            if server_major_int
              "Install pg_dump at PostgreSQL #{server_version}: yum install -y postgresql#{server_major_int}"
            else
              "Install pg_dump: yum install -y postgresql"
            end
          when :arch
            "Install pg_dump: pacman -S postgresql"
          when :alpine
            if server_major_int
              "Install pg_dump at PostgreSQL #{server_version}: apk add postgresql#{server_major_int}-client"
            else
              "Install pg_dump: apk add postgresql-client"
            end
          else
            if server_version
              "Install pg_dump at PostgreSQL #{server_version} or newer via your package manager"
            else
              "Install pg_dump: Install PostgreSQL client tools for your distribution"
            end
          end
        end
        # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

        def postgresql_server_version
          result = ActiveRecord::Base.connection.execute("SELECT version();")
          return nil unless result.any?

          version_string = result.first["version"]
          version_string.match(/PostgreSQL (\d+\.\d+)/)&.[](1)
        rescue StandardError
          nil
        end

        def psql_version
          output, status = Open3.capture2("psql --version 2>&1")
          return nil unless status.success?

          output.strip.match(/(\d+\.\d+)/)&.[](1)
        end

        def pg_dump_version
          output = `pg_dump --version 2>&1`.strip
          return nil unless $CHILD_STATUS.success?

          output.match(/(\d+\.\d+)/)&.[](1)
        end

        def upgrade_pg_dump_hint(server_major_version)
          os_info = detect_os
          case os_info[:type]
          when :debian
            # rubocop:disable Layout/LineLength
            "Upgrade pg_dump to PostgreSQL #{server_major_version}:\n  " \
            "curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /usr/share/keyrings/postgresql.gpg\n  " \
            "echo \"deb [signed-by=/usr/share/keyrings/postgresql.gpg] http://apt.postgresql.org/pub/repos/apt $(grep VERSION_CODENAME /etc/os-release | cut -d= -f2 | tr -d '\"')-pgdg main\" | tee /etc/apt/sources.list.d/pgdg.list\n  " \
            "apt-get update && apt-get install -y postgresql-client-#{server_major_version}"
            # rubocop:enable Layout/LineLength
          when :fedora
            "Upgrade pg_dump to PostgreSQL #{server_major_version}: dnf install -y postgresql#{server_major_version}"
          when :rhel
            "Upgrade pg_dump to PostgreSQL #{server_major_version}: yum install -y postgresql#{server_major_version}"
          when :arch
            "Upgrade pg_dump: pacman -Syu postgresql"
          when :alpine
            "Upgrade pg_dump to PostgreSQL #{server_major_version}: apk add postgresql#{server_major_version}-client"
          else
            "Upgrade pg_dump to PostgreSQL #{server_major_version} or newer via your package manager"
          end
        end

        def install_tar_hint(os_info)
          case os_info[:type]
          when :debian, :fedora, :rhel, :arch, :alpine
            "Install tar: Usually pre-installed. If missing, install via your package manager."
          else
            "Install tar: Install via your system's package manager"
          end
        end

        def upgrade_psql_hint(server_major_version)
          os_info = detect_os
          case os_info[:type]
          when :debian
            # rubocop:disable Layout/LineLength
            "Upgrade psql to PostgreSQL #{server_major_version}:\n  " \
            "curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /usr/share/keyrings/postgresql.gpg\n  " \
            "echo \"deb [signed-by=/usr/share/keyrings/postgresql.gpg] http://apt.postgresql.org/pub/repos/apt $(grep VERSION_CODENAME /etc/os-release | cut -d= -f2 | tr -d '\"')-pgdg main\" | tee /etc/apt/sources.list.d/pgdg.list\n  " \
            "apt-get update && apt-get install -y postgresql-client-#{server_major_version}"
            # rubocop:enable Layout/LineLength
          when :fedora
            "Upgrade psql to PostgreSQL #{server_major_version}: dnf install -y postgresql#{server_major_version}"
          when :rhel
            "Upgrade psql to PostgreSQL #{server_major_version}: yum install -y postgresql#{server_major_version}"
          when :arch
            "Upgrade psql: pacman -Syu postgresql"
          when :alpine
            "Upgrade psql to PostgreSQL #{server_major_version}: apk add postgresql#{server_major_version}-client"
          else
            "Upgrade psql to PostgreSQL #{server_major_version} or newer via your package manager"
          end
        end

        # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
        def detect_os
          os_release_path = "/etc/os-release"
          return { type: :unknown } unless File.exist?(os_release_path)

          os_release = {}
          File.readlines(os_release_path).each do |line|
            key, value = line.strip.split("=", 2)
            next unless key && value

            value = value.delete_prefix('"').delete_suffix('"')
            os_release[key.downcase] = value
          end

          id = os_release["id"]&.downcase
          id_like = os_release["id_like"]&.downcase

          if id == "ubuntu" || id == "debian" || id_like&.include?("debian")
            { type: :debian, id: }
          elsif id == "fedora" || id_like&.include?("fedora")
            { type: :fedora, id: }
          elsif id == "centos" || id == "rhel" || id_like&.include?("rhel") || id_like&.include?("centos")
            { type: :rhel, id: }
          elsif id == "arch" || id_like&.include?("arch")
            { type: :arch, id: }
          elsif id == "alpine"
            { type: :alpine, id: }
          else
            { type: :unknown, id: }
          end
        end
        # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

        private

        def check_psql_available!
          unless system("which", "psql", out: File::NULL, err: File::NULL)
            os_info = detect_os
            hints = install_psql_hint(os_info)
            raise("Missing required binary: psql\n\n#{hints}")
          end
        end

        # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
        def install_psql_hint(os_info)
          server_version = postgresql_server_version
          server_major_int = server_version&.split(".")&.first&.to_i

          case os_info[:type]
          when :debian
            if server_major_int
              # rubocop:disable Layout/LineLength
              "Install psql at PostgreSQL #{server_version}:\n  " \
                "curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /usr/share/keyrings/postgresql.gpg\n  " \
                "echo \"deb [signed-by=/usr/share/keyrings/postgresql.gpg] http://apt.postgresql.org/pub/repos/apt $(grep VERSION_CODENAME /etc/os-release | cut -d= -f2 | tr -d '\"')-pgdg main\" | tee /etc/apt/sources.list.d/pgdg.list\n  " \
                "apt-get update && apt-get install -y postgresql-client-#{server_major_int}"
              # rubocop:enable Layout/LineLength
            else
              "Install psql: apt-get update && apt-get install -y postgresql-client"
            end
          when :fedora
            if server_major_int
              "Install psql at PostgreSQL #{server_version}: dnf install -y postgresql#{server_major_int}"
            else
              "Install psql: dnf install -y postgresql"
            end
          when :rhel
            if server_major_int
              "Install psql at PostgreSQL #{server_version}: yum install -y postgresql#{server_major_int}"
            else
              "Install psql: yum install -y postgresql"
            end
          when :arch
            "Install psql: pacman -S postgresql"
          when :alpine
            if server_major_int
              "Install psql at PostgreSQL #{server_version}: apk add postgresql#{server_major_int}-client"
            else
              "Install psql: apk add postgresql-client"
            end
          else
            if server_version
              "Install psql at PostgreSQL #{server_version} or newer via your package manager"
            else
              "Install psql: Install PostgreSQL client tools for your distribution"
            end
          end
        end
        # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

        def check_postgresql_version_compatibility!
          server_version = postgresql_server_version
          client_version = psql_version

          return unless server_version && client_version

          return if client_version >= server_version

          server_major_int = server_version.split(".").first.to_i
          hints = upgrade_psql_hint(server_major_int)
          raise("Version mismatch: psql #{client_version} is older than PostgreSQL server #{server_version}. " \
                "Upgrade psql to match or exceed server version.\n\n#{hints}")
        end

        def check_database_permissions!
          ActiveRecord::Base.connection_pool.with_connection do |conn|
            result = conn.execute(
              "SELECT rolcreatedb, rolsuper, rolname FROM pg_roles WHERE rolname = current_user"
            )

            next unless result.any?

            row = result.first
            username = row["rolname"]
            has_createdb = row["rolcreatedb"] == true || row["rolcreatedb"] == "t"
            is_superuser = row["rolsuper"] == true || row["rolsuper"] == "t"

            next if is_superuser || has_createdb

            raise("Database user '#{username}' lacks CREATEDB privilege. " \
                  "Grant CREATEDB privilege: ALTER USER #{username} CREATEDB;")
          end
        rescue ActiveRecord::ConnectionNotEstablished, ActiveRecord::NoDatabaseError => e
          raise("Cannot check database permissions: #{e.message}. " \
                "Ensure database connection is configured and accessible.")
        rescue StandardError => e
          raise("Failed to check database permissions: #{e.message}")
        end
      end
    end
  end
end
