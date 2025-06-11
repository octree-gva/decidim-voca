# frozen_string_literal: true

namespace :assets do
  desc "Precompile assets with custom configurations"
  task precompile: :environment do
    # Your custom precompilation logic here
    Rake::Task["assets:convert_webp"].invoke
  end

  desc "Create .webp versions of assets"
  task convert_webp: :environment do
    image_types = /\.(?:png|jpe?g)$/

    public_assets = Rails.public_path.join("decidim-packs").to_s

    Dir["#{public_assets}/**/*"].each do |filename|
      next unless filename =~ image_types

      mtime = File.mtime(filename)
      webp_file = "#{filename}.webp"
      next if File.exist?(webp_file) && File.mtime(webp_file) >= mtime

      begin
        # encode with lossy encoding and slowest method (best quality)
        WebP.encode(filename, webp_file, lossless: 0, quality: 80, method: 6)
        File.utime(mtime, mtime, webp_file)
        $stdout.puts "Converted image to Webp: #{webp_file}"
      rescue StandardError => e
        warn "Webp conversion error on image #{webp_file}. Error info: #{e.message}"
      end
    end
  end
end
