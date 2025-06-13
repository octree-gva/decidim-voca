workspace {
  model {   
    user = person "Participant"
    cacheSystem =  softwareSystem "cache" "" "External" {
      cache = container "cache" "" "memcached" "External"
    }
    
    databaseSystem =  softwareSystem "database" "" "External" {
      db = container "database" "" "postgres" "External"
    }

    decidimSystem = softwareSystem "decidim-voca" "decidim with decidim-voca" {
      decidimVoca = container "decidim-voca" "decidim with decidim-voca module" {
        proxy = component "reverse-proxy" "" "Nginx"
        app = component "decidim" "`puma` process" "Decidim"
        worker = component "active-job" "`good_queue` process" "Decidim"
        
        user -> proxy "request a page" ""
        proxy -> app "pass the request" ""
        app -> db "enqueue invalidation for url" ""
        app -> app "compute HTML"
        app -> cacheSystem "read/write cache" ""
        app -> user "serve a cached page"
        
        worker -> db "fetch urls to regenerates" ""
        worker -> cacheSystem "write cache" ""
      }
    }

    deploymentEnvironment "Live" {
        deploymentNode "public" "" "" "" 1 {
         dns = infrastructureNode "DNS router" {
              technology "traefik"
              description "routes incoming requests based upon domain name."
              tags "External"
          }
        }

        toolInstance = deploymentNode "tools" "" "environment" "" 1 {
          dbToolInstance = infrastructureNode "sqldb"{
              technology "Postgis"
          }            
          dbCacheInstance = infrastructureNode "cache"{
              technology "Memcached"
          }
        }
        vocaInstance = deploymentNode "decidim" "" "decidim/decidim" "" 1 {
          appInstance = containerInstance decidimVoca
        }

        dns -> appInstance
        appInstance -> dbCacheInstance
        appInstance -> dbToolInstance
    }
  }
  
  views {

    theme https://git.octree.ch/decidim/vocacity/decidim-modules/decidim-voca/-/snippets/38/raw/main/theme.json
    themes https://git.octree.ch/decidim/vocacity/decidim-modules/decidim-voca/-/snippets/38/raw/main/theme.json
    styles {
      relationship "Relationship" {
          color #293845
          dashed true
          thickness 2
          fontSize 14
          width 550
          routing direct
      }
    }
    branding {
      font default https://fonts.googleapis.com/css2?family=Inter:ital,opsz,wght@0,14..32,100..900;1,14..32,100..900&display=swap
    }
    
    systemcontext decidimSystem "cache-system"{
      title "Cache system overview"
      include user
      include decidimSystem->app
      autoLayout lr
    }
    deployment decidimSystem "Live" "cache-infra" {
        title "Infrastructure for caching"
        include *

        autoLayout
    }

    dynamic decidimVoca "cache-middleware" {
      title "Cache logics"
      proxy -> app 
      app -> cacheSystem "find cache for request.path"
      app -> app "if not found, generate a new cache"
      app -> db "enqueue url to renew, delay: 5min"
      autoLayout tb
    }
    dynamic decidimVoca "cache-containers" {
        title "Cache: Container overview"
        user -> proxy 
        proxy -> app 
        app -> cacheSystem 
        app -> user
        autoLayout tb
    }

    dynamic decidimVoca "cache-invalidation" {
        title "How cache invalidation works"
        app -> db 
        worker -> db 
        worker -> cacheSystem 
        autoLayout tb
    }
  }
}