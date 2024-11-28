require 'opentelemetry/sdk'
# Load the Rails application.
require_relative 'application'

OpenTelemetry::SDK.configure(&:use_all)

# Initialize the Rails application.
Rails.application.initialize!
