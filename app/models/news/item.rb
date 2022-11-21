module News
  class Item < Sequel::Model(:news_items)
    plugin :timestamps
    plugin :auto_validations, not_null: :presence

    DISPLAY_REGULAR = 0
    MAX_SLUG_LENGTH = 254

    many_to_many :collections, join_table: :news_collections_news_items,
                               order: :name

    def collection_ids=(ids)
      @collection_ids = normalise_ids(ids)
    end

    def collection_ids
      @collection_ids ||= collections.pluck(:id)
    end

    def reload
      @collection_ids = nil

      super
    end

    def before_validation
      super

      @collection_ids = normalise_ids(collection_ids)
      generate_or_normalise_slug!
    end

    def after_save
      to_add = collection_ids - collections.pluck(:id)
      to_add.each(&method(:add_collection))

      to_remove = collections.pluck(:id) - collection_ids
      to_remove.each(&method(:remove_collection))
    end

    def validate
      super

      validates_presence :slug
    end

    dataset_module do
      def descending
        order(Sequel.desc(:start_date), Sequel.desc(:id))
      end

      def for_today
        where { start_date <= Time.zone.today }
        .where { (end_date >= Time.zone.today) | { end_date: nil } }
      end

      def for_service(service_name)
        case service_name.to_s
        when 'uk' then where(show_on_uk: true)
        when 'xi' then where(show_on_xi: true)
        else self
        end
      end

      def for_target(target_name)
        case target_name.to_s
        when 'home' then where(show_on_home_page: true)
        when 'updates' then where(show_on_updates_page: true)
        when 'banner' then where(show_on_banner: true)
        else self
        end
      end
    end

    private

    def normalise_ids(ids)
      Array.wrap(ids).map(&:presence).compact.map(&:to_i).uniq
    end

    def generate_or_normalise_slug!
      current_slug = slug.presence || title.presence
      return unless current_slug

      normalised_slug = normalise_slug(slug.presence || title)
      self.slug = normalised_slug if slug != normalised_slug
    end

    def normalise_slug(slug)
      slug.downcase.gsub(/\s+/, '-').gsub(/[^a-z0-9-]/, '').first(MAX_SLUG_LENGTH)
    end
  end
end
