
def webmock_setup_defaults
  allowed = []

  if ENV.key?('ELASTICSEARCH_URL')
    url = URI.parse(ENV['ELASTICSEARCH_URL'])
    allowed << url.host
    allowed.uniq!
  end

  WebMock.disable_net_connect!(allow_localhost: true, allow: allowed)
end

webmock_setup_defaults
