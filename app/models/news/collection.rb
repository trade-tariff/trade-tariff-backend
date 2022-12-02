module News
  class Collection < Sequel::Model(:news_collections)
    plugin :timestamps
    plugin :auto_validations, not_null: :presence

    many_to_many :items, join_table: :news_collections_news_items,
                         order: Sequel.desc(:start_date)

    set_dataset order(Sequel.desc(:priority), :name)

    def validate
      super

      validates_presence :slug
      validates_format %r{\A[a-z0-9\-_]+\z}, :slug if slug.present?
    end
  end
end
