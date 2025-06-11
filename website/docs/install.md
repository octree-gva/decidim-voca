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
```

**Install the module**  
```bash
bundle install
```

**Compile assets**  
```bash
bin/rails assets:precompile
```