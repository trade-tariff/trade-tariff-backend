unless Rails.env.test?
  Rails.application.config.to_prepare do
    Search::Metrics.subscribe!
  end
end
