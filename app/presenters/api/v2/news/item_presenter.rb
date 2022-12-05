module Api
  module V2
    module News
      class ItemPresenter < SimpleDelegator
        class << self
          def wrap(items)
            items.map(&method(:new))
          end
        end

        def collections
          published_collections
        end

        def collection_ids
          published_collections.map(&:id)
        end
      end
    end
  end
end
