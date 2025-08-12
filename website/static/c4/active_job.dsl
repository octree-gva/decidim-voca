workspace {
  model {   
    user = person "Participant"
    
    databaseSystem =  softwareSystem "database" "" "External" {
      db = container "database" "" "postgres" "External"
    }

    decidimSystem = softwareSystem "decidim-voca" "decidim with decidim-voca" {
      decidimVoca = container "decidim-voca" "decidim with decidim-voca module" {
        app = component "decidim" "`puma` process" "Decidim"
        user -> app "ask for a new password"
        app -> db "enqueue sending email" ""
        app -> app 
      }
      goodJobContainer = container "good_job" "good_job" {
        good_job_external = component "active-job" "`good_job` process" "Decidim"
        good_job_external -> db "pull new queues" ""
        good_job_external -> good_job_external "compute email" ""
        good_job_external -> user "send email" ""
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

        deploymentNode "database" "" "environment" "" 1 {
          dbInstance = infrastructureNode "sqldb"{
              technology "Postgres"
          }            
        }
        vocaInstance = deploymentNode "decidim" "" "decidim/decidim" "" 1 {
          appInstance = containerInstance decidimVoca
          goodJobInstance = containerInstance goodJobContainer
        }

        nginx -> appInstance
        appInstance -> dbInstance
        goodJobInstance -> dbInstance
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
    
    deployment decidimSystem "Live" "good-job-external-infra" {
        title "__External__ mode infrastructure"
        include appInstance
        include goodJobInstance
        include dbInstance
        include nginx
        autoLayout
    }

    deployment decidimSystem "Live" "good-job-async-infra" {
        title "__Async Server__ mode infrastructure"
        include appInstance
        include dbInstance
        include nginx
        autoLayout
    }

    dynamic decidimVoca "good-job-external-logics" {
      title "__External__ mode: Sending a password reset email"
      user -> app "request a new password" ""
      app -> db "enqueue sending email" ""
      good_job_external -> db "pull new queues" ""
      good_job_external -> user "send email" ""
      autoLayout
    }
    dynamic decidimVoca "good-job-internal-logics" {
      title "__Async Server__ mode: Sending a password reset email"
      user -> app "request a new password" ""
      app -> db "enqueue sending email" ""
      app -> db "pull new queues" ""
      app -> user "send email" ""
      autoLayout tb
    }


  }
}