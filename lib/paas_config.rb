module PaasConfig
  module_function

  def redis
    url = begin
      # TODO: !Important
      # need to fetch by service name if we use multiple redis services
      JSON.parse(ENV['VCAP_SERVICES'])['redis'][0]['credentials']['uri']
    rescue
      ENV['REDIS_URL']
    end

    { url: url, db: 0, id: nil }
  end

  def elasticsearch
    url = begin
      # TODO: !Important
      # need to fetch by service name if we use multiple elasticsearch services
      JSON.parse(ENV['VCAP_SERVICES'])['elasticsearch'][0]['credentials']['uri']
    rescue
      ENV['ELASTICSEARCH_URL']
    end

    { url: url }
  end

  def space
    JSON.parse(ENV['VCAP_APPLICATION'])['space_name']
  rescue
    Rails.env
  end
end
