module Reporting
  class Commodities
    include Reporting::Reportable

    class << self
      def generate
        with_report_logging do
          records = instrument_report_step('load_rows') do
            TimeMachine.now { goods_nomenclatures }
          end

          log_report_metric('rows_written', records.size)

          csv_data = instrument_report_step('serialize_csv', rows_written: records.size) do
            Api::Admin::Csv::GoodsNomenclatureSerializer
              .new(records)
              .serialized_csv
          end

          log_report_metric('output_bytes', csv_data.bytesize)

          if Rails.env.development?
            instrument_report_step('write_local_file', output_bytes: csv_data.bytesize) do
              File.write(File.basename(object_key), csv_data)
            end
          end

          if Rails.env.production?
            instrument_report_step('upload', output_bytes: csv_data.bytesize) do
              object.put(
                body: csv_data,
                content_type: 'text/csv',
              )
            end
          end
        end
      end

      def get_today
        Reporting.get_published(object_key)
      end

      def get_xi_today
        Reporting.get_published(xi_object_key)
      end

      def get_uk_today
        Reporting.get_published(uk_object_key)
      end

      def get_uk_link_today
        Reporting.published_link(uk_object_key)
      end

      def get_xi_link_today
        Reporting.published_link(xi_object_key)
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
        if Rails.env.development?
          "commodities_xi_#{now.strftime('%Y_%m_%d')}.csv"
        else
          "xi/reporting/#{year}/#{month}/#{day}/commodities_xi_#{now.strftime('%Y_%m_%d')}.csv"
        end
      end

      def uk_object_key
        if Rails.env.development?
          "commodities_uk_#{now.strftime('%Y_%m_%d')}.csv"
        else
          "uk/reporting/#{year}/#{month}/#{day}/commodities_uk_#{now.strftime('%Y_%m_%d')}.csv"
        end
      end
    end
  end
end
