# Settings that models read from the process environment. Models ask this
# class, so they do not need TradeTariffBackend, which lives outside the
# models pack.
#
# TradeTariffBackend reads the same variables. It does not call this class,
# because some rake tasks load TradeTariffBackend without autoloading
# app/models.
class DeploymentSettings
  class << self
    def support_email
      ENV['TARIFF_SUPPORT_EMAIL']
    end

    def frontend_host
      ENV['FRONTEND_HOST']
    end

    def label_page_size
      ENV.fetch('GOODS_NOMENCLATURE_LABEL_PAGE_SIZE', '10').to_i
    end

    def environment
      ActiveSupport::StringInquirer.new(ENV.fetch('ENVIRONMENT', 'local'))
    end
  end
end
