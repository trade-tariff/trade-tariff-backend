# Rack::QueryParser handles nested query parameters by converting square brackets ([]) in query parameter names to
# to structured hashes. This is called nested query parameters.
#
# API gateway does not support naming nested query parameters as cache/request parameter keys so we require a dot-separated
# syntax instead on the api.<base_domain> path.
#
# This middleware converts dot-separated nested query parameter names back to canonical ones so the application doesn't
# need to be taught to handle each case separately.
class HandleApiGatewayParams
  SEPARATOR = '.'.freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    req = Rack::Request.new(env)
    query_hash = req.GET
    nested_keys = query_hash.keys.grep(/#{SEPARATOR}/)
    nested_keys.each do |key|
      value = query_hash.delete(key)
      next if value.nil?

      nested = build_nested(key, value)
      query_hash = deep_merge(query_hash, nested)
    end

    req.set_header(Rack::RACK_REQUEST_QUERY_HASH, query_hash)
    req.set_header(Rack::QUERY_STRING, Rack::Utils.build_nested_query(query_hash))

    status, headers, body = @app.call(req.env)

    [status, headers, body]
  end

  private

  def build_nested(key, value)
    keys = key.split(SEPARATOR)
    last_key = keys.pop
    keys.reverse.inject({ last_key => value }) { |acc, k| { k => acc } }
  end

  def deep_merge(old, new)
    old.merge(new) do |_, old_val, new_val|
      if old_val.is_a?(Hash) && new_val.is_a?(Hash)
        deep_merge(old_val, new_val)
      else
        new_val
      end
    end
  end
end
