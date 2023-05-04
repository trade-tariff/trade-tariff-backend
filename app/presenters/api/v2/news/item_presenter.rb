module Api
  module V2
    module News
      class ItemPresenter < WrapDelegator
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
