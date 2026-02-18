module News
  class Collection < Sequel::Model(:news_collections)
    plugin :timestamps, update_on_create: true
    plugin :auto_validations, not_null: :presence

    many_to_many :items, join_table: :news_collections_news_items,
                         order: Sequel.desc(:start_date)

    set_dataset order(Sequel.desc(:priority), :name)

    dataset_module do
      def published
        where(published: true)
      end
    end

    def validate
      validates_presence :slug
      validates_unique :slug, :name
      validates_format %r{\A[a-z0-9\-_]+\z}, :slug if slug.present?

      super
    end
  end
end
