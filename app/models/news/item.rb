module News
  class Item < Sequel::Model(:news_items)
    plugin :timestamps
    plugin :auto_validations, not_null: :presence

    DISPLAY_REGULAR = 0

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
    end

    def after_save
      (collection_ids - collections.pluck(:id)).each(&method(:add_collection))
      (collections.pluck(:id) - (collection_ids & collections.pluck(:id)))
        .each(&method(:remove_collection))
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
      Array.wrap(ids).map(&:to_i).compact.uniq
    end
  end
end