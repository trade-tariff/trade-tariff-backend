module Api
  module Admin
    class SearchReferencesController < AdminController
      include Api::Admin::VersionBrowsing

      def index
        search_references = SearchReference.for_usage(usage_filter).for_letter(letter).all

        render json: Api::Admin::SearchReferences::SearchReferenceListSerializer.new(search_references).serializable_hash
      end

      def show
        render json: Api::Admin::SearchReferences::SearchReferenceSerializer.new(
          search_reference,
          serializer_options,
        ).serializable_hash
      end

      def export
        send_data Api::Admin::Csv::SearchReferenceSerializer.new(SearchReference.admin_export).serialized_csv,
                  filename: "search_references_#{TradeTariffBackend.service}_#{date}.csv",
                  type: 'text/csv',
                  disposition: 'attachment'
      end

    private

      def date
        Time.zone.today.strftime('%Y_%m_%d')
      end

      def letter
        params.dig(:query, :letter) || ''
      end

      def usage_filter
        usage = params.dig(:filter, :usage)
        SearchReference::USAGE_FILTERS.include?(usage) ? usage : SearchReference::SEARCH_USAGE
      end

      def search_reference
        @search_reference ||= (current_version? && current_search_reference) || reified_search_reference
      end

      def current_search_reference
        @current_search_reference ||= SearchReference.where(id: params[:id].to_i).first
      end

      # Used for historical versions and for references that no longer exist,
      # so operators can see the last known state of a deleted reference.
      def reified_search_reference
        version = viewed_version
        raise Sequel::RecordNotFound if version.blank?

        version.reify
      end

      def versions_for_item
        Version.where(item_type: 'SearchReference', item_id: params[:id].to_s)
      end
    end
  end
end
