---
sidebar_position: 3
slug: /cache
title: Cache
description: Serve static HTML pages whenever you can
---

# Cache
> **N.B** Be sure you have read again the [Caching with rails documentation](https://guides.rubyonrails.org/caching_with_rails.html) before using our cache. 

![Cache System](/c4/images/structurizr-cache-system.png)

The module `decidim-voca` introduce a request-level cache that will cache some page as plain HTML. 
We explain in this document how the cache works. 

To make this work, you will need to adapt your infrastructure in order to have an efficient cache. 
We **strongly** suggest you use `Memcache` server, has it is performant, easy to scale up, and need much less expertise than redis to maintain. (see [Using Memcached Section](#using-memcached)) 

![Infrastructure adaptation](/c4/images/structurizr-cache-infra.png)

We expect you have the the following infrastructure: 

- A process to reverse-proxy requests to decidim
- A process running decidim 
- A process an active-job worker
- A postgres database
- A memcached server
- An access to a S3 bucket
- A CDN that distribute this bucket

For simpliciy, we assume you use an active-job worker like [GoodJob](https://github.com/bensheldon/good_job) or [SideKick](https://github.com/sidekiq/sidekiq).

## Cache middleware
![Infrastructure adaptation](/c4/images/structurizr-cache-middleware.png)  
`decidim-voca` insert a middleware at the very beginning of the stack, to check if the request is a candidate to have been cached:
- `request.method` should be a `GET` request
- warden cookie (used under the hoods by devise) should be absent
- `request.format` should be html
- `request.xhr?` should be false. 


Once we sure the request is candidate to cache, we: 
- Check if the cache have `request.path` (with parameters) 
- If the cache exists
  - return immeditaly the HTML without going further in the stack
- If the cache does not exists
  - continue and cache the page

**Dangers**  
Caching at the request level gives great performances, and cames with big responsabilities: 
- `ActiveStorage` in `redirect_mode` generates images that are valid for a limit amount of time
- Forms use a `CSRF` token to avoid replay attack. This token is stored in the `<head>` of the HTML, and will be _systematically_ expired.

We need then strategies to attends this situation.

## Cache invalidation
![Cache invalidation process](/c4/images/structurizr-cache-invalidation.png)  


## Using Memcached

Set the cache store to `mem_cache_store` in your `production.rb`

```
config.cache_store = :mem_cache_store
```

The set your environment variables `MEMCACHE_SERVERS`. You can add more than one server, separating by comma.
