# Rack Timeout Configuration
# See: https://github.com/zombocom/rack-timeout
#
# RACK_TIMEOUT_WAIT_TIMEOUT (seconds, default: 30)
# Maximum time a request is allowed to have waited in the web server queue before
# reaching the application. Requests exceeding this are expired/dropped without processing.
# Current setting: 100 seconds
ENV['RACK_TIMEOUT_WAIT_TIMEOUT'] ||= '100'

# RACK_TIMEOUT_SERVICE_TIMEOUT (seconds, default: 15)
# Maximum time the application can take to process and respond to a request once received.
# Requests exceeding this will be terminated (SIGTERM sent to worker).
# Current setting: 50 seconds
ENV['RACK_TIMEOUT_SERVICE_TIMEOUT'] ||= '50'

# Other available settings (using defaults if not set):
# - RACK_TIMEOUT_WAIT_OVERTIME: Additional wait time for requests with a body (POST, PUT, etc.) (default: 60)
# - RACK_TIMEOUT_SERVICE_PAST_WAIT: Whether to use full service_timeout even after wait_timeout (default: false)
# - RACK_TIMEOUT_TERM_ON_TIMEOUT: Send SIGTERM when timeout occurs (default: 0/false)
