if Rails.env.production?
  Rails.application.config.xray = {
    name: 'trade-tariff-backend',
  }
end
