require_relative 'config/ai'
require_relative 'config/alcohol'
require_relative 'config/authentication'
require_relative 'config/email'
require_relative 'config/goods_nomenclature'
require_relative 'config/green_lanes'
require_relative 'config/infrastructure'
require_relative 'config/opensearch'
require_relative 'config/redis'
require_relative 'config/reporting'
require_relative 'config/service_context'
require_relative 'config/slack'
require_relative 'config/tariff_sync'
require_relative 'config/xe'

module TradeTariffBackend
  module Config
    include AI
    include Alcohol
    include Authentication
    include Email
    include GoodsNomenclature
    include GreenLanes
    include Infrastructure
    include Opensearch
    include Redis
    include Reporting
    include ServiceContext
    include Slack
    include TariffSync
    include XE
  end
end
