module News
  class Importer
    DEFAULT_ITEMS_FILENAME = Rails.root.join('db/news/govuk_stories.json').freeze
    NEWS_ITEM_KEYS = %w[
      headline
      slug
      precis
      story
      validity_start_date
      validity_end_date
      themes
    ].freeze

    class << self
      def import!(src_file = DEFAULT_ITEMS_FILENAME)
        new(src_file).import!
      end
    end

    def initialize(src_file)
      @src_file = src_file
    end

    def stories
      @stories ||= JSON.parse(@src_file.read)['news'] || []
    end

    def import!
      raise NotAvailableOnXi if TradeTariffBackend.xi?

      import_time = Time.zone.now

      ::News::Item.db.transaction do
        create_news_collections

        stories.each { |story| import_story(story, import_time) }
        stories.length
      end
    end

    class NotAvailableOnXi < RuntimeError; end
    class InvalidData < RuntimeError; end

  private

    def import_story(item_data, import_time)
      raise InvalidData unless data_has_all_keys?(item_data)

      item = News::Item.create(
        title: item_data['headline'],
        slug: item_data['slug'],
        precis: item_data['precis'],
        content: item_data['story'],
        start_date: item_data['validity_start_date'],
        end_date: item_data['validity_end_date'],
        display_style: News::Item::DISPLAY_REGULAR,
        show_on_uk: true,
        show_on_xi: true,
        show_on_updates_page: true,
        show_on_banner: false,
        show_on_home_page: false,
        imported_at: import_time,
      )

      get_news_collections(item_data['themes']).each do |collection|
        item.add_collection collection
      end
    end

    def data_has_all_keys?(story)
      NEWS_ITEM_KEYS.all? { |k| story.key?(k) }
    end

    def get_news_collections(names)
      names.split(',').map(&method(:get_news_collection))
    end

    def get_news_collection(name)
      normalised_name = name.gsub(/[^a-z0-9 ]/i, '')

      @collections[normalised_name] ||= create_news_collection(normalised_name)
    end

    def create_news_collections
      @collections = [
        create_tariff_notices,
        create_stop_press,
        create_trade_news,
        create_service_updates,
      ].index_by(&:name)
    end

    def create_tariff_notices
      create_news_collection 'Tariff notices', 3, <<~DESCRIPTION
        ## Contact details

        <div class="address govuk-inset-text">
          Tariff Classification
          <br>Customs Directorate
          <br>10th Floor South East
          <br>Alexander House
          <br>21 Victoria Avenue
          <br>Southend-on-Sea
          <br>Essex SS99 1AA
        </div>

        Email: [tariff.classification@hmrc.gov.uk](mailto:tariff.classification@hmrc.gov.uk)

        This Tariff notice is published for information purposes only.
      DESCRIPTION
    end

    def create_stop_press
      create_news_collection 'Tariff stop press', 2, <<~DESCRIPTION
        ## More information

        To stop getting the Tariff stop press notices, or to add recipients to
        the distribution list, email: [tariff.management@hmrc.gov.uk](mailto:tariff.management@hmrc.gov.uk).
      DESCRIPTION
    end

    def create_trade_news
      create_news_collection 'Trade news', 1
    end

    def create_service_updates
      create_news_collection 'Service updates', 0
    end

    def create_news_collection(name, priority = nil, description = nil)
      collection = Collection.find_or_create(name:)
      collection.priority = priority if priority
      collection.description = description if description
      collection.save

      collection
    end
  end
end
