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

        instrument("#{name}#generate") do
          if category_assessments.any?
            json = instrument("#{name}#serializable_hash") { serialized_assessments.serializable_hash.to_json }

            instrument("#{name}#upload") do
              zipped = zip(json, File.basename(object_key))

              if Rails.env.development?
                File.write(zipped[:filename], zipped[:data], mode: 'wb')
              end

              if Rails.env.production?
                object.put(body: zipped[:data], content_type: zipped[:content_type])
              end
            end
          else
            Rails.logger.info('No Category Assessments found; report not generated.')
          end
        end
      end

      private

      def serialized_assessments
        instrument do
          Api::V2::GreenLanes::CategoryAssessmentSerializer.new(
            category_assessments,
            include: %w[geographical_area excluded_geographical_areas exemptions theme regulation measure_type],
          )
        end
      end

      def category_assessments
        @category_assessments ||= begin
          cas = instrument("#{name}#category_assessments") do
            GreenLanes::CategoryAssessment.eager(CATEGORY_ASSESSMENTS_EAGER).all
          end

          instrument("#{name}#presenters") do
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
