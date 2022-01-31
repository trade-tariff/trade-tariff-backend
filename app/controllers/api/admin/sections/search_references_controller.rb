module Api
  module Admin
    module Sections
      class SearchReferencesController < Api::Admin::SearchReferencesBaseController
        private

        def search_reference_collection
          section.search_references_dataset
        end

        def search_reference_resource_association_hash
          { referenced: section }
        end

        def collection_url
          [:admin, section, @search_reference]
        end

        def section
          @section ||= Section.with_pk!(params[:section_id])
        end
      end
    end
  end
end
