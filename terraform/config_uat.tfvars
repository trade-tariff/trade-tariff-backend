region          = "eu-west-2"
environment     = "uat"
cpu             = 1024
memory          = 2048
service_count   = 1
min_capacity_uk = 1
min_capacity_xi = 1
max_capacity    = 2

# The common stack creates these values again on each UAT start (RFC 002 in
# trade-tariff-platform-aws-terraform, "Generated values").
generated_secrets = {
  backend-uk = {
    DATABASE_URL        = "uat-postgres-database-url"
    READER_DATABASE_URL = "aurora-postgres-ro-connection-string"
    REDIS_URL           = "valkey-backend-uk-connection-string"
    SIDEKIQ_REDIS_URL   = "valkey-sidekiq-uk-connection-string"
    FRONTEND_REDIS_URL  = "valkey-frontend-connection-string"
  }
  worker-uk = {
    DATABASE_URL        = "uat-postgres-database-url"
    READER_DATABASE_URL = "aurora-postgres-ro-connection-string"
    REDIS_URL           = "valkey-backend-uk-connection-string"
    SIDEKIQ_REDIS_URL   = "valkey-sidekiq-uk-connection-string"
    FRONTEND_REDIS_URL  = "valkey-frontend-connection-string"
  }
  backend-xi = {
    DATABASE_URL        = "uat-postgres-database-url"
    READER_DATABASE_URL = "aurora-postgres-ro-connection-string"
    REDIS_URL           = "valkey-backend-xi-connection-string"
    SIDEKIQ_REDIS_URL   = "valkey-sidekiq-xi-connection-string"
    FRONTEND_REDIS_URL  = "valkey-frontend-connection-string"
  }
  worker-xi = {
    DATABASE_URL        = "uat-postgres-database-url"
    READER_DATABASE_URL = "aurora-postgres-ro-connection-string"
    REDIS_URL           = "valkey-backend-xi-connection-string"
    SIDEKIQ_REDIS_URL   = "valkey-sidekiq-xi-connection-string"
    FRONTEND_REDIS_URL  = "valkey-frontend-connection-string"
  }
  backend-job = {
    DATABASE_URL        = "uat-postgres-database-url"
    READER_DATABASE_URL = "aurora-postgres-ro-connection-string"
    REDIS_URL           = "valkey-backend-uk-connection-string"
    SIDEKIQ_REDIS_URL   = "valkey-sidekiq-uk-connection-string"
    FRONTEND_REDIS_URL  = "valkey-frontend-connection-string"
  }
}

generated_parameters = {
  backend-uk  = { ELASTICSEARCH_URL = "/uat/ELASTICSEARCH_URL" }
  worker-uk   = { ELASTICSEARCH_URL = "/uat/ELASTICSEARCH_URL" }
  backend-xi  = { ELASTICSEARCH_URL = "/uat/ELASTICSEARCH_URL" }
  worker-xi   = { ELASTICSEARCH_URL = "/uat/ELASTICSEARCH_URL" }
  backend-job = { ELASTICSEARCH_URL = "/uat/ELASTICSEARCH_URL" }
}
