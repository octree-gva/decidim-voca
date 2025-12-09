workspace {
  model {   
    user = person "Participant"
    
    redisSystem = softwareSystem "redis" "" "External" {
      redis = container "redis" "Redis" "redis" "External"
    }

    traefikSystem = softwareSystem "traefik" "" "External" {
      traefik = container "traefik" "Traefik" "traefik" "External"
    }

    decidimSystemA = softwareSystem "decidim-voca A" "decidim with decidim-voca" {
      decidimVocaA = container "decidim-voca A" "decidim with decidim-voca module" {
        appA = component "decidim A" "`puma` process" "Decidim"
        appA -> redis "sync routes"
      }
    }

    decidimSystemB = softwareSystem "decidim-voca B" "decidim with decidim-voca" {
      decidimVocaB = container "decidim-voca B" "decidim with decidim-voca module" {
        appB = component "decidim B" "`puma` process" "Decidim"
        appB -> redis "sync routes"
      }
    }

    traefik -> redis "read routes"
    user -> traefik "access application"

    deploymentEnvironment "Live" {
        deploymentNode "decidim-a" "" "environment" "" 1 {
          decidimAInstance = containerInstance decidimVocaA
        }

        deploymentNode "decidim-b" "" "environment" "" 1 {
          decidimBInstance = containerInstance decidimVocaB
        }

        deploymentNode "redis" "" "environment" "" 1 {
          redisInstance = infrastructureNode "redis" {
            technology "Redis"
            tags "External"
          }
        }

        deploymentNode "traefik" "" "environment" "" 1 {
          traefikInstance = infrastructureNode "traefik" {
            technology "Traefik"
            tags "External"
          }
        }

        decidimAInstance -> redisInstance "sync routes"
        decidimBInstance -> redisInstance "sync routes"
        traefikInstance -> redisInstance "read routes"
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
    
    deployment decidimSystemA "Live" "routing-infra" {
        title "Redis routing infrastructure"
        include decidimAInstance
        include decidimBInstance
        include redisInstance
        include traefikInstance
        autoLayout
    }

    dynamic decidimVocaA "routing-sync-logics" {
      title "Route synchronization flow"
      appA -> redis "sync routes"
      appB -> redis "sync routes"
      traefik -> redis "read routing"
      traefik -> user "exposes application"
      autoLayout
    }
  }
}

