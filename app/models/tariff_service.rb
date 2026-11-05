# Says which tariff the process serves: 'uk' or 'xi'. The SERVICE environment
# variable sets it when the process starts. Models ask this class, so they do
# not need TradeTariffBackend, which lives outside the models pack.
#
# TradeTariffBackend.service reads the same variable. It does not call this
# class, because some rake tasks load TradeTariffBackend without autoloading
# app/models.
class TariffService
  class << self
    def current
      ENV.fetch('SERVICE', 'uk')
    end

    def uk?
      current == 'uk'
    end

    def xi?
      current == 'xi'
    end
  end
end
