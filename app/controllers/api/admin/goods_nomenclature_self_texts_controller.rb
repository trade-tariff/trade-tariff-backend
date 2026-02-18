module Api
  module Admin
    class GoodsNomenclatureSelfTextsController < AdminController
      def index
        render json: serialized_collection
      end

      private

      def serialized_collection
        GoodsNomenclatures::GoodsNomenclatureSelfTextSerializer.new(
          paginated_dataset.all,
          is_collection: true,
          meta: pagination_meta,
        ).serializable_hash
      end

      def pagination_meta
        {
          pagination: {
            page: current_page,
            per_page:,
            total_count: paginated_dataset.pagination_record_count,
          },
        }
      end

      def paginated_dataset
        @paginated_dataset ||= filtered_dataset.paginate(current_page, per_page)
      end

      SCORE_SQL = <<~SQL.squish
        CASE
          WHEN "goods_nomenclature_self_texts"."similarity_score" IS NOT NULL
           AND "goods_nomenclature_self_texts"."coherence_score" IS NOT NULL
          THEN ("goods_nomenclature_self_texts"."similarity_score" + "goods_nomenclature_self_texts"."coherence_score") / 2.0
          WHEN "goods_nomenclature_self_texts"."similarity_score" IS NOT NULL
          THEN "goods_nomenclature_self_texts"."similarity_score"
          WHEN "goods_nomenclature_self_texts"."coherence_score" IS NOT NULL
          THEN "goods_nomenclature_self_texts"."coherence_score"
        END
      SQL

      def filtered_dataset
        st = Sequel[:goods_nomenclature_self_texts]

        dataset = GoodsNomenclatureSelfText.dataset
          .join(:goods_nomenclatures, goods_nomenclature_sid: :goods_nomenclature_sid)
          .select_all(:goods_nomenclature_self_texts)
          .select_append(
            Sequel.lit("CASE WHEN \"goods_nomenclatures\".\"producline_suffix\" = '80' THEN 'commodity' ELSE 'subheading' END").as(:nomenclature_type),
            Sequel.lit(SCORE_SQL).as(:score),
          )
          .where(st[:generation_type] => 'ai')

        dataset = apply_type_filter(dataset)
        dataset = apply_status_filter(dataset)
        dataset = apply_score_filter(dataset)
        apply_sorting(dataset)
      end

      def apply_type_filter(dataset)
        gn = Sequel[:goods_nomenclatures]

        case params[:type]
        when 'commodity'
          dataset.where(gn[:producline_suffix] => '80')
        when 'subheading'
          dataset.exclude(gn[:producline_suffix] => '80')
        else
          dataset
        end
      end

      def apply_status_filter(dataset)
        st = Sequel[:goods_nomenclature_self_texts]

        case params[:status]
        when 'needs_review'
          dataset.where(st[:needs_review] => true)
        when 'stale'
          dataset.where(st[:stale] => true)
        when 'manually_edited'
          dataset.where(st[:manually_edited] => true)
        else
          dataset
        end
      end

      def apply_score_filter(dataset)
        score = Sequel.lit("(#{SCORE_SQL})")

        case params[:score_category]
        when 'bad'
          dataset.where(score < 0.3)
        when 'okay'
          dataset.where(score >= 0.3).where(score < 0.5)
        when 'good'
          dataset.where(score >= 0.5).where(score < 0.85)
        when 'amazing'
          dataset.where(score >= 0.85)
        when 'no_score'
          dataset.where(Sequel.lit("(#{SCORE_SQL}) IS NULL"))
        else
          dataset
        end
      end

      def apply_sorting(dataset)
        col = sort_column
        dir = sort_direction == 'desc' ? :desc : :asc

        dataset.order(Sequel.public_send(dir, col, nulls: :last))
      end

      def sort_column
        allowed = {
          'score' => Sequel.lit('score'),
          'goods_nomenclature_item_id' => Sequel[:goods_nomenclature_self_texts][:goods_nomenclature_item_id],
        }

        allowed[params[:sort]] || Sequel.lit('score')
      end

      def sort_direction
        %w[asc desc].include?(params[:direction]) ? params[:direction] : 'asc'
      end
    end
  end
end
