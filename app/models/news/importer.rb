module News
  class Importer
    DEFAULT_ITEMS_FILE = Rails.root.join('db/news/govuk_stories.json').freeze
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
      def import!(src_file = DEFAULT_ITEMS_FILE)
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

      ::News::Item.db.transaction do
        stories.each(&method(:import_story)).length
      end
    end

    class NotAvailableOnXi < RuntimeError; end
    class InvalidData < RuntimeError; end

  private

    def import_story(item_data)
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
      )

      get_collections(item_data['themes']).each do |collection|
        item.add_collection collection
      end
    end

    def data_has_all_keys?(story)
      NEWS_ITEM_KEYS.all? { |k| story.key?(k) }
    end

    def get_collections(names)
      names.split(',').map(&method(:get_collection))
    end

    def get_collection(name)
      normalised_name = name.gsub(/[^a-z0-9 ]/i, '')

      @collections ||= {}
      @collections[normalised_name] ||= Collection.find_or_create(name: normalised_name)
    end
  end
end
