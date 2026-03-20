module Reporting
  class CategoryAssessments
    extend Reporting::Reportable

    CATEGORY_ASSESSMENTS_EAGER = {
      theme: [],
      base_regulation: [],
      modification_regulation: [],
      measure_type: %i[measure_type_description measure_type_series_description],
      measures: {
        additional_code: :additional_code_descriptions,
        measure_conditions: { certificate: %i[certificate_descriptions exempting_certificate_override] },
        geographical_area: :geographical_area_descriptions,
        measure_excluded_geographical_areas: [],
        excluded_geographical_areas: :geographical_area_descriptions,
      },
      green_lanes_measures: :goods_nomenclature,
      exemptions: [],
    }.freeze

    class << self
      def generate
        return unless TradeTariffBackend.xi?

        with_report_logging do
          if category_assessments.any?
            log_report_metric('rows_written', category_assessments.size)

            json = instrument_report_step('serialize_json', rows_written: category_assessments.size) do
              serialized_assessments.serializable_hash.to_json
            end

            instrument_report_step('package_output') do
              basename = File.basename(object_key)
              zipped = zip(json, basename.gsub('.zip', '.json'))

              log_report_metric('output_bytes', zipped[:data].bytesize)

              if Rails.env.development?
                File.write(zipped[:filename], zipped[:data], mode: 'wb')
              end

              if Rails.env.production?
                instrument_report_step('upload', output_bytes: zipped[:data].bytesize) do
                  object.put(body: zipped[:data], content_type: zipped[:content_type])
                end
              end
            end
          else
            log_report_metric('rows_written', 0)
          end
        end
      end

      private

      def serialized_assessments
        Api::V2::GreenLanes::CategoryAssessmentSerializer.new(
          category_assessments,
          include: %w[geographical_area excluded_geographical_areas exemptions theme regulation measure_type],
        )
      end

      def category_assessments
        @category_assessments ||= begin
          cas = instrument_report_step('load_rows') do
            GreenLanes::CategoryAssessment.eager(CATEGORY_ASSESSMENTS_EAGER).all
          end

          instrument_report_step('build_presenters') do
            Api::V2::GreenLanes::CategoryAssessmentPresenter.wrap(cas)
          end
        end
      end

      def object_key
        "#{service}/reporting/#{year}/#{month}/#{day}/category_assessments_#{service}_#{now.strftime('%Y_%m_%d')}.zip"
      end
    end
  end
end
