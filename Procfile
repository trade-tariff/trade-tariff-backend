web: DB_POOL="${DB_POOL:-${MAX_THREADS:-6}}" bundle exec rake cf:run_migrations db:migrate && DB_POOL="${DB_POOL:-${MAX_THREADS:-6}}" bundle exec puma -C config/puma.rb
worker1: DB_POOL="${DB_POOL:-${SIDEKIQ_CONCURRENCY:-10}}" bundle exec sidekiq -C ./config/sidekiq.yml
worker2: DB_POOL="${DB_POOL:-${SIDEKIQ_CONCURRENCY:-10}}" bundle exec sidekiq -C ./config/sidekiq.yml
