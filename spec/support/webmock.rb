def webmock_setup_defaults
  allowed = []

  if ENV['ELASTICSEARCH_VPC_URL'].present? || ENV.key?('ELASTICSEARCH_URL')
    url = URI.parse(TradeTariffBackend.opensearch_host)
    allowed << url.host
    allowed.uniq!
  end

  WebMock.disable_net_connect!(allow_localhost: true, allow: allowed)
end

webmock_setup_defaults
