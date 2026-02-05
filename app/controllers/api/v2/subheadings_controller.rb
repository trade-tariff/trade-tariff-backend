module Api
  module V2
    class SubheadingsController < ApiController
      include SearchResultTracking

      before_action :track_result_selected, only: :show

      def show
        render json: cached_subheading
      end

      private

      def cached_subheading
        CachedSubheadingService.new(
          subheading,
          actual_date.iso8601,
        ).call
      end

      def subheading_code
        params[:id].split('-', 2).first
      end

      def productline_suffix
        params[:id].split('-', 2)[1] || '80'
      end

      def subheading
        Subheading.actual
                  .non_hidden
                  .by_code(subheading_code)
                  .by_productline_suffix(productline_suffix)
                  .take
                  .tap { |sh| raise Sequel::RecordNotFound if sh.leaf? }
      end
    end
  end
end
