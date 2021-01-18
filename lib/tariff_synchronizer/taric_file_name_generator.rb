module TariffSynchronizer
  class TaricFileNameGenerator
    attr_reader :date
    delegate :taric_query_url_template, :taric_update_url_template, :host, to: TariffSynchronizer

    def initialize(date)
      @date = date
    end

    def url
      format(taric_query_url_template, host: host, date: date.strftime('%Y%m%d'))
    end

    def get_info_from_response(string)
      string
        .split("\n")
        .map { |name| remove_invalid_characters(name) }
        .map { |name| { filename: local_filename(name), url: update_url(name) } }
    end

  private

    def update_url(name)
      format(taric_update_url_template, host: host, filename: name)
    end

    def local_filename(name)
      "#{date}_#{name}"
    end

    def remove_invalid_characters(name)
      name.gsub(/[^0-9a-zA-Z\.]/i, '')
    end
  end
end
