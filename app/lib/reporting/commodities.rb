module Reporting
  class Commodities
    extend Reporting::Reportable

    class << self
      def generate
        TimeMachine.now do
          csv_data = Api::Admin::Csv::GoodsNomenclatureSerializer
              .new(goods_nomenclatures)
              .serialized_csv

          File.write(File.basename(object_key), csv_data) if Rails.env.development?

          if Rails.env.production?
            object.put(
              body: csv_data,
              content_type: 'text/csv',
            )
          end

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

      def object_key
        "#{service}/reporting/#{year}/#{month}/#{day}/commodities_#{service}_#{now.strftime('%Y_%m_%d')}.csv"
      end

      def xi_object_key
        "xi/reporting/#{year}/#{month}/#{day}/commodities_xi_#{now.strftime('%Y_%m_%d')}.csv"
      end

      def uk_object_key
        "uk/reporting/#{year}/#{month}/#{day}/commodities_uk_#{now.strftime('%Y_%m_%d')}.csv"
      end
    end
  end
end
