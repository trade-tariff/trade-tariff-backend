# Using elasticsearch paas service
require 'paas_config'

ENV['ELASTICSEARCH_URL'] = PaasConfig.elasticsearch[:url]
