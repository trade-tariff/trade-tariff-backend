module Api
  module Admin
    module Chapters
      class SearchReferencesController < Api::Admin::SearchReferencesBaseController
        private

        def search_reference_collection
          chapter.search_references_dataset
        end

        def search_reference_resource_association_hash
          { referenced: chapter }
        end

        def collection_url
          [:admin, chapter, @search_reference]
        end

        def chapter
          @chapter ||= Chapter.by_code(chapter_id).take
        end

        def chapter_id
          params[:chapter_id]
        end
      end
    end
  end
end
