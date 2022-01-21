module TariffSynchronizer
  # TODO: Remove once Taric has fixed their api
  class TaricFileNameGeneratorPatched
    delegate :taric_query_url_template, :taric_update_url_template, :host, to: TariffSynchronizer

    def initialize(url_filename)
      @url_filename = url_filename
    end

    def url
      sprintf(taric_update_url_template, host: host, filename: @url_filename)
    end
  end
end
