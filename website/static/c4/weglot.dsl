workspace {
  model {   
    user = person "Participant"
    weglotSystem =  softwareSystem "weglot" "" "External" {
      weglot = container "weglot" "" "weglot" "External"
    }

    databaseSystem =  softwareSystem "database" "" "External" {
      db = container "database" "" "postgres" "External"
    }

    decidimSystem = softwareSystem "decidim-voca" "decidim with decidim-voca" {
      decidimVoca = container "decidim-voca" "decidim with decidim-voca module" {
        app = component "decidim" "`puma` process" "Decidim"

        user -> weglot "access the app"
        weglot -> app "translate content"
        weglot -> user "gives translated content" 
      }

    }

    deploymentEnvironment "Live" {
        deploymentNode "public" "" "" "" 1 {
         nginx = infrastructureNode "Reverse Proxy" {
              technology "nginx"
              description "routes incoming requests based upon domain name."
              tags "External"
          }
        }
        deploymentNode "weglot" "" "environment" "" 1 {
          weglotInstance = infrastructureNode "external"{
              technology "Weglot"
              tags "External"
          }            
        }

        deploymentNode "database" "" "environment" "" 1 {
          dbInstance = infrastructureNode "sqldb"{
              technology "Postgres"
          }            
        }
        vocaInstance = deploymentNode "decidim" "" "decidim/decidim" "" 1 {
          appInstance = containerInstance decidimVoca
        }
        weglotInstance -> nginx
        nginx -> appInstance
        appInstance -> dbInstance
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
    
    deployment decidimSystem "Live" "weglot-infra" {
        title "Infrastructure with weglot"
        include weglotInstance
        include appInstance
        include dbInstance
        include nginx
        autoLayout
    }


    dynamic decidimVoca "weglot-translation-logics" {
      title "Content translation with Weglot"
      user -> weglot "access the app"
      weglot -> app "translate content"
      weglot -> user "gives translated content" 
      autoLayout
    }

  }
}