workers Integer(ENV['WEB_CONCURRENCY'] || 2)
threads_count = Integer(ENV['MAX_THREADS'] || 6)
threads threads_count, threads_count

preload_app!

rackup      Puma::Configuration::DEFAULTS[:rackup]
port        ENV['PORT']     || 8080
environment ENV['RACK_ENV'] || 'development'

cert = ENV['SSL_CERT_PEM']&.gsub("\\n", "\n")
key  = ENV['SSL_KEY_PEM']&.gsub("\\n", "\n")

puts "SSL_CERT present? #{ENV['SSL_CERT_PEM'].present?}"
puts "SSL_KEY present? #{ENV['SSL_KEY_PEM'].present?}"
puts "SSL_PORT: #{ENV['SSL_PORT']}"

if cert.present? && key.present?
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
