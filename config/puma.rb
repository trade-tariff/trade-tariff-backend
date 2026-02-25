workers Integer(ENV['WEB_CONCURRENCY'] || 2)
threads_count = Integer(ENV['MAX_THREADS'] || 6)
threads threads_count, threads_count

preload_app!

rackup      Puma::Configuration::DEFAULTS[:rackup]
# port        ENV['PORT']     || 8080
environment ENV['RACK_ENV'] || 'development'

# Explicit HTTP bind,  default is 8080.
bind "tcp://0.0.0.0:#{ENV.fetch('PORT', 8080)}"

# Explicit HTTPS bind
cert = ENV['SSL_CERT_PEM']&.gsub("\\n", "\n")
key  = ENV['SSL_KEY_PEM']&.gsub("\\n", "\n")

if cert.to_s != "" && key.to_s != ""
  ssl_bind '0.0.0.0', ENV.fetch('SSL_PORT', 8443),
           cert_pem: cert,
           key_pem: key
end

on_worker_boot do
  # Ensure we don't keep connections
  if defined?(Sequel)
    ::Sequel::Model.db.disconnect
    ::Sequel::DATABASES.each(&:disconnect)
  end
end

after_worker_boot do
  SequelRails.setup Rails.env if defined?(SequelRails)
end
