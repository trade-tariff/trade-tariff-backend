require 'csv'

module Api
  module V2
    class GoodsNomenclaturesController < ApiController
      before_action :set_request_format, only: %w[show_by_section show_by_chapter show_by_heading]

      def index
        commodities = Chapter.non_hidden
                             .eager(:ns_descendants)
                             .all
                             .flat_map(&:ns_descendants)

        respond_with(commodities)
      end

      def show_by_section
        section  = Section.where(position: params[:position]).take
        chapters = section.chapters_dataset
                          .non_hidden
                          .eager(:goods_nomenclature_descriptions,
                                 :goods_nomenclature_indents,
                                 ns_descendants: :goods_nomenclature_descriptions)
                          .all

        @goods_nomenclatures = chapters.flat_map { |ch| [ch] + ch.ns_descendants }

        respond_with(@goods_nomenclatures)
      end

      def show_by_chapter
        chapter = Chapter.actual
                         .non_hidden
                         .by_code(params[:chapter_id])
                         .eager(ns_descendants: :goods_nomenclature_descriptions)
                         .limit(1)
                         .all
                         .first
                         .presence || (raise Sequel::RecordNotFound)

        @goods_nomenclatures = [chapter] + chapter.ns_descendants

        respond_with(@goods_nomenclatures)
      end

      def show_by_heading
        headings = Heading.actual
                          .non_hidden
                          .by_code(params[:heading_id])
                          .eager(ns_descendants: :goods_nomenclature_descriptions)
                          .all

        raise Sequel::RecordNotFound if headings.empty?

        @goods_nomenclatures = headings.flat_map do |heading|
          [heading] + heading.ns_descendants
        end

        respond_with(@goods_nomenclatures)
      end

      def self.api_path_builder(object, check_for_subheadings: false)
        gnid = object.goods_nomenclature_item_id
        return nil unless gnid

        case object
        when Chapter
          "/api/v2/chapters/#{gnid.first(2)}"
        when Heading
          "/api/v2/headings/#{gnid.first(4)}"
        when Subheading
          "/api/v2/subheadings/#{object.to_param}"
        else
          if check_for_subheadings && !object.ns_declarable?
            "/api/v2/subheadings/#{object.to_param}"
          else
            "/api/v2/commodities/#{gnid.first(10)}"
          end
        end
      end
      helper_method :api_path_builder

      private

      def respond_with(commodities)
        @commodities = commodities
        response.set_header('Date', actual_date.httpdate)

        respond_to do |format|
          format.json do
            headers['Content-Type'] = 'application/json'
            render json: Api::V2::GoodsNomenclatures::GoodsNomenclatureExtendedSerializer.new(@goods_nomenclatures.to_a).serializable_hash
          end
          format.csv do
            send_data(
              Api::V2::Csv::GoodsNomenclatureSerializer.new(@goods_nomenclatures).serialized_csv,
              type: 'text/csv; charset=utf-8; header=present',
              disposition: "attachment; filename=goods-nomenclatures-for-as-of-#{actual_date.iso8601}.csv",
            )
          end
        end
      end

      def action
        {
          show_by_section: 'section',
          show_by_chapter: 'chapter',
          show_by_heading: 'heading',
          show_by_commodity: 'commodity',
        }[params[:action].to_sym]
      end

      def set_request_format
        request.format = :csv if request.headers['CONTENT_TYPE'] == 'text/csv'
      end
    end
  end
end
