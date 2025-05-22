module News
  class Item < Sequel::Model(:news_items)
    plugin :timestamps, update_on_create: true
    plugin :auto_validations, not_null: :presence

    DISPLAY_REGULAR = 0
    MAX_SLUG_LENGTH = 254

    many_to_many :collections, join_table: :news_collections_news_items
    plugin :association_dependencies, collections: :nullify

    many_to_many :published_collections, join_table: :news_collections_news_items,
                                         conditions: { published: true },
                                         right_key: :collection_id,
                                         class_name: '::News::Collection'

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

      StopPressSubscriptionWorker.perform_async(id)
    end

    def validate
      super

      validates_presence :slug
      validates_presence :precis if show_on_updates_page
      validates_presence :collection_ids, message: 'must include at least one collection'
      errors.add(:chapters, 'have an invalid format') unless chapters.to_s.split.all? { |chapter| chapter.match?(/\A\d{2}\z/) }
    end

    def cache_key_with_version
      "News::Item/#{id}-#{updated_at}"
    end

    def emailable?
      collections.any?(&:subscribable) && notify_subscribers
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

      def for_year(year)
        year = year.presence&.to_i
        return self unless year

        first_of_jan = Time.zone.parse("#{year}-01-01 00:00:00")
        where(start_date: first_of_jan..first_of_jan.end_of_year)
      end

      def for_collection(collection_id)
        collection_id = collection_id.presence

        scope = association_join(:published_collections).select_all(:news_items)

        if collection_id.to_s.match? %r{\A\d+\z}
          scope.where(collection_id: collection_id.to_i)
        elsif collection_id
          scope.where { published_collections[:slug] =~ collection_id }
        else
          scope
        end
      end

      def years
        distinct.select { date_part('year', :start_date).cast(:integer).as(:year) }
                .order(Sequel.desc(:year))
                .pluck(:year)
      end

      def latest_change
        order(Sequel.desc(:updated_at)).first
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
