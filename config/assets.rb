# frozen_string_literal: true

base_path = File.expand_path("..", __dir__)

Decidim::Webpacker.register_path("#{base_path}/app/packs")
Decidim::Webpacker.register_entrypoints(
  decidim_voca: "#{base_path}/app/packs/entrypoints/decidim-voca.scss",
  admin_decidim_voca: "#{base_path}/app/packs/entrypoints/admin-decidim-voca.scss",
  decidim_voca_js: "#{base_path}/app/packs/entrypoints/decidim-voca.js",
  admin_decidim_voca_js: "#{base_path}/app/packs/entrypoints/admin-decidim-voca.js"
)
