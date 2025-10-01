require 'csv'

module Api
  module V2
    class GoodsNomenclaturesController < ApiController
      before_action :set_request_format, only: %w[show_by_section show_by_chapter show_by_heading]

      def index
        commodities = Chapter.non_hidden
                             .eager(:ancestors,
                                    descendants: :goods_nomenclature_descriptions)
                             .all
                             .flat_map(&:descendants)

        respond_with(commodities)
      end

      def show
        gn = GoodsNomenclature
               .actual
               .association_inner_join(:goods_nomenclature_indents)
               .where(Sequel[:goods_nomenclatures][:goods_nomenclature_item_id] => params[:id])
               .order(Sequel[:goods_nomenclatures][:producline_suffix], Sequel[:goods_nomenclature_indents][:number_indents])
               .last

        raise Sequel::RecordNotFound if gn.blank?

        render json: Api::V2::GoodsNomenclatures::GoodsNomenclatureExtendedSerializer.new(gn).serializable_hash
      end

      def show_by_section
        section  = Section.where(position: params[:position]).take
        chapters = section.chapters_dataset
                          .non_hidden
                          .eager(:goods_nomenclature_descriptions,
                                 :goods_nomenclature_indents,
                                 :ancestors,
                                 descendants: :goods_nomenclature_descriptions)
                          .all

        @goods_nomenclatures = chapters.flat_map { |ch| [ch] + ch.descendants }

        respond_with(@goods_nomenclatures)
      end

      def show_by_chapter
        chapter = Chapter.actual
                         .non_hidden
                         .by_code(params[:chapter_id])
                         .eager(:ancestors,
                                descendants: :goods_nomenclature_descriptions)
                         .take

        @goods_nomenclatures = [chapter] + chapter.descendants

        respond_with(@goods_nomenclatures)
      end

      def show_by_heading
        headings = Heading.actual
                          .non_hidden
                          .by_code(params[:heading_id])
                          .eager(:ancestors,
                                 descendants: :goods_nomenclature_descriptions)
                          .all

        raise Sequel::RecordNotFound if headings.empty?

        @goods_nomenclatures = headings.flat_map do |heading|
          [heading] + heading.descendants
        end

        respond_with(@goods_nomenclatures)
      end

      def show_by_batch
        commodity_codes = bulk_commmodities_params[:commodity_codes]
        include_expired = params[:include_expired] == 'true'

        if commodity_codes.size > 10
          render json: serialize_errors({ error: 'Maximum of 10 commodity codes allowed' }),
                 status: :unprocessable_entity
          return
        end

        gns = if include_expired
                load_with_expired(commodity_codes)
              else
                load_actual(commodity_codes)
              end

        @goods_nomenclatures = gns.flat_map { |gn| [gn] }
        respond_with(@goods_nomenclatures)
      end

      def self.api_path_builder(object, check_for_subheadings: false)
        service = TradeTariffBackend.service
        gnid = object.goods_nomenclature_item_id
        return nil unless gnid

        case object
        when Chapter
          "/#{service}/api/chapters/#{gnid.first(2)}"
        when Heading
          "/#{service}/api/headings/#{gnid.first(4)}"
        when Subheading
          "/#{service}/api/subheadings/#{object.to_param}"
        else
          if check_for_subheadings && !object.declarable?
            "/#{service}/api/subheadings/#{gnid.first(10)}-#{object.producline_suffix}"
          else
            "/#{service}/api/commodities/#{gnid.first(10)}"
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

      def bulk_commmodities_params
        params.require(:data).require(:attributes).permit(
          commodity_codes: [],
        )
      end

      def serialize_errors(errors)
        Api::User::ErrorSerializationService.new.serialized_errors(errors)
      end

      def scope(codes)
        GoodsNomenclature.actual
          .association_inner_join(:goods_nomenclature_indents)
          .where(Sequel[:goods_nomenclatures][:goods_nomenclature_item_id] => codes)
          .eager(:ancestors)
          .order(
            Sequel[:goods_nomenclatures][:producline_suffix],
            Sequel[:goods_nomenclature_indents][:number_indents],
            Sequel[:goods_nomenclatures][:validity_start_date].desc,
          )
      end

      def load_with_expired(codes)
        gns = []

        codes.each do |code|
          latest_gn = GoodsNomenclature
                        .where(goods_nomenclature_item_id: code)
                        .order(Sequel.desc(:validity_start_date))
                        .first
          next unless latest_gn

          TimeMachine.at(latest_gn.validity_start_date) do
            gns << scope(code).take
          end
        end

        gns
      end

      def load_actual(codes)
        codes.filter_map do |code|
          scope(code)
            .order(Sequel.desc(:number_indents))
            .first
        end
      end
    end
  end
end
