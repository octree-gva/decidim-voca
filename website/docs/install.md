---
sidebar_position: 2
slug: /install
title: Installation
description: How to install the module
---

### Support Table
| Decidim Version | Supported?  |
|-----------------|-------------|
| 0.24            | no          |
| 0.26            | no         |
| 0.27            | no         |
| 0.28            | no          |
| 0.29            | yes         |

# Install Decidim Voca

**Add the gem to your Gemfile**  
```ruby
gem "decidim-voca", "~> 0.0.1"
gem "next_gen_images", git: "https://github.com/froger/next_gen_images", branch: "chore/rails-7.0"
gem "deface", "1.9.0", git: "https://github.com/froger/deface", branch: "fix/js-overrides"
gem "good_job", "~> 4.5.1"
```

**Install dependances for webp**  
on debian: 
```
apt-get update -yq
apt-get install -yq --no-install-recommends \
    libxrender1 \
    libjpeg-dev \
    libpng-dev \
    libtiff-dev \
    libwebp-dev \
    libvips \
    libvips-tools
```
on ubuntu: 
```
apt-get update -yq
apt-get install -yq --no-install-recommends \
    libfftw3-dev \
    libxrender1 \
    libjpeg-dev \
    libpng-dev \
    libjpeg-turbo8-dev \
    libwebp-dev \
    libvips \
    libvips-dev \
    libvips-tools
```

**Install the module**  
```bash
bundle install
bundle exec rails voca:webpacker:install
bundle exec rails decidim_voca:install:migrations 
bundle exec rails db:migrate
```

**Compile assets**  
```bash
bundle exec rails assets:precompile
```

**(prod only) Compile overrides**  
```bash
bundle exec rails bundle exec rails deface:precompile
``` 
And set `Rails.application.config.deface.enabled=false` in your `production.rb`