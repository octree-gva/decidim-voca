---
sidebar_position: 5
slug: /telemetry
title: Telemetry
description: Improve observability on your Decidim
---

# Telemetry
Telemetry use behind the hood the gem [Yabeda](https://github.com/yabeda-rb/yabeda) to: 

- Expose healthpoint and metrics endpoint
- Format response to be compatible with prometheus and open-telemetry
- Mesure intensive workload 
  - Comment, proposal and user creation
  - Votes on comment and proposal
  - Overall decidim activity (all active support notifications sent)
- Mesure specific activities: 
  - Puma workers and threads
  - Ruby on Rails time requests
  - Active Job statuses
  - DB Connections


## Installation
Add in your installation decidim telemetry
```
  bundle add decidim-telemetry --git https://git.octree.ch/decidim/vocacity/decidim-modules/decidim-telemetry --ref v0.0.1
`` 
or add it in your Gemfile:

```ruby
# Gemfile
gem "decidim-telemetry", 
  git: "https://git.octree.ch/decidim/vocacity/decidim-modules/decidim-telemetry", 
  tag: "v0.0.1" # check decidim-voca.gemspec to know wich version is compatible with your install
```

Once installed, [follow the installation guidances](https://git.octree.ch/decidim/vocacity/decidim-modules/decidim-telemetry)

## References

- [Decidim Telemtry gem](https://git.octree.ch/decidim/vocacity/decidim-modules/decidim-telemetry)
- [Yabeda](https://github.com/yabeda-rb/yabeda)
- [Yabeda Puma](https://github.com/yabeda-rb/yabeda-puma-plugin)
- [Yabeda Active Record](https://github.com/yabeda-rb/yabeda-activerecord)
- [Yabeda Active Job](https://github.com/Fullscript/yabeda-activejob)
- [Yabeda Rails](https://github.com/yabeda-rb/yabeda-rails)
