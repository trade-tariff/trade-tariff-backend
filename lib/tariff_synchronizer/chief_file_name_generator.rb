module TariffSynchronizer
  class ChiefFileNameGenerator
    attr_reader :date
    delegate :chief_update_url_template, :host, to: TariffSynchronizer

    def initialize(date)
      @date = date
    end

    def name
      "#{date}_#{file_name}"
    end

    def url
      format(chief_update_url_template, host: host, file_name: file_name)
    end

  private

    def file_name
      "KBT009(#{date.strftime('%y')}#{year_day_with_3_characters}).txt"
    end

    def year_day_with_3_characters
      sprintf('%03d', date.yday)
    end
  end
end
