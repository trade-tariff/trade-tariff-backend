module Reporting
  class Commodities
    extend Reporting::Reportable

    class << self
      def generate
        TimeMachine.now do
          csv_data = Api::Admin::Csv::GoodsNomenclatureSerializer
              .new(goods_nomenclatures)
              .serialized_csv

          object.put(
            body: csv_data,
            content_type: 'text/csv',
          )

          Rails.logger.debug("Query count: #{::SequelRails::Railties::LogSubscriber.count}")
        end
      end

      def get_today
        Reporting.get(object_key)
      end

      def get_xi_today
        Reporting.get(xi_object_key)
      end

      def get_uk_today
        Reporting.get(uk_object_key)
      end

      def get_uk_link_today
        Reporting.get_link(uk_object_key)
      end

      def get_xi_link_today
        Reporting.get_link(xi_object_key)
      end

      def get_days_ago(days_ago = 0)
        Reporting.get(object_key(days_ago))
      end

      def get_xi_days_ago(days_ago = 0)
        Reporting.get(xi_object_key(days_ago))
      end

      def get_uk_days_ago(days_ago = 0)
        Reporting.get(uk_object_key(days_ago))
      end

      def get_uk_link_days_ago(days_ago = 0)
        Reporting.get_link(uk_object_key(days_ago))
      end

      def get_xi_link_days_ago(days_ago = 0)
        Reporting.get_link(xi_object_key(days_ago))
      end

      private

      def goods_nomenclatures
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

      def object_key(days_ago = 0)
        "#{service}/reporting/#{year(days_ago)}/#{month(days_ago)}/#{day(days_ago)}/commodities_#{service}_#{now(days_ago).strftime('%Y_%m_%d')}.csv"
      end

      def xi_object_key(days_ago = 0)
        "xi/reporting/#{year(days_ago)}/#{month(days_ago)}/#{day(days_ago)}/commodities_xi_#{now(days_ago).strftime('%Y_%m_%d')}.csv"
      end

      def uk_object_key(days_ago = 0)
        "uk/reporting/#{year(days_ago)}/#{month(days_ago)}/#{day(days_ago)}/commodities_uk_#{now(days_ago).strftime('%Y_%m_%d')}.csv"
      end
    end
  end
end
