module Reporting
  class Commodities
    extend Reporting::Reportable
    extend Reporting::Csvable

    class << self
      def generate
        save_document(object, object_key, csv_data)
        log_query_count
      end

      def csv_data
        Api::Admin::Csv::GoodsNomenclatureSerializer
          .new(goods_nomenclatures)
          .serialized_csv
      end

      def get_today
        Reporting.get(object_key)
      end

      def get_xi_today
        Reporting.get(object_key(service: 'xi'))
      end

      def get_uk_today
        Reporting.get(object_key(service: 'uk'))
      end

      def get_uk_link_today
        Reporting.get_link(object_key(service: 'uk'))
      end

      def get_xi_link_today
        Reporting.get_link(object_key(service: 'xi'))
      end

      private

      def goods_nomenclatures
        TimeMachine.now do
          Chapter
            .non_hidden
            .eager(
              :goods_nomenclature_descriptions,
              ancestors: :goods_nomenclature_descriptions,
              descendants: :goods_nomenclature_descriptions,
            )
            .all
            .each_with_object([]) do |chapter, acc|
              acc << chapter
              acc.concat chapter.descendants
            end
        end
      end

      def object_key(tariff = service)
        "#{object_key_prefix(tariff)}/commodities_#{object_key_suffix(tariff)}.csv"
      end
    end
  end
end
