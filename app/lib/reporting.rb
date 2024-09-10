module Reporting
  extend Reportable

  def self.get(object_key)
    # if Rails.env.production?
    #   object(object_key).get.body.read
    # else

    File.open(object_key)
    # end
  end

  def self.get_link(object_key)
    # if Rails.env.production?
    #   File.join(TradeTariffBackend.reporting_cdn_host, object_key)
    # else
    object_key
    # end
  end
end
