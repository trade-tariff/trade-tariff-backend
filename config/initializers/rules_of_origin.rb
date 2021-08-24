unless Rails.env.test?
  Rails.application.reloader.to_prepare do
    RulesOfOrigin::SchemeSet.current =
      RulesOfOrigin::SchemeSet.new \
        Rails.root.join \
          "db/rules_of_origin/roo_schemes_#{TradeTariffBackend.service}.json"
  end
end
