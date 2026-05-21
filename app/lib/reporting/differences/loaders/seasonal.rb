module Reporting
  class Differences
    class Loaders
      class Seasonal
        include Reporting::Differences::Loaders::Helpers

        delegate :each_chapter,
                 to: :report

        DUTY_STATUSES = {
          start_date: 'Different start date, same end date',
          no_duty: 'No duty found',
        }.freeze

        private

        def data
          acc = []

          each_seasonal_measure { |measure| acc << build_row_for(measure) }

          acc.compact
        end

        def build_row_for(measure)
          [
            measure.goods_nomenclature_item_id,
            measure.geographical_area_id,
            measure.measure_type_id,
            measure.validity_start_date,
            measure.validity_end_date,
            measure.failed_duty_status,
          ]
        end

        def each_seasonal_measure
          seasonal_measures.map do |seasonal_measure|
            applicable_measure = applicable_measures[seasonal_measure]

            seasonal_measure.failed_duty_status = if applicable_measure
                                                    DUTY_STATUSES[:start_date] if applicable_measure.validity_start_date != seasonal_measure.validity_start_date
                                                  else
                                                    DUTY_STATUSES[:no_duty]
                                                  end

            yield seasonal_measure if seasonal_measure.failed_duty_status.present?
          end
        end

        def applicable_measures
          @applicable_measures ||= begin
            measures = Measure
              .with_seasonal_measures(measure_type_ids, geographical_area_ids)
              .all

            PresentedMeasure.wrap(measures).index_by { |measure| measure }
          end
        end

        def seasonal_measures
          @seasonal_measures ||= CSV.parse(File.read('db/seasonal_measures.csv'), headers: true).map do |row|
            PresentedSeasonalMeasure.new(row)
          end
        end

        def measure_type_ids
          seasonal_measures.pluck(:measure_type_id).uniq
        end

        def geographical_area_ids
          seasonal_measures.pluck(:geographical_area_id).uniq
        end

        class PresentedMeasure < WrapDelegator
          def hash
            [
              goods_nomenclature_item_id,
              geographical_area_id,
              measure_type_id,
              self[:validity_end_date].to_date.iso8601,
            ].hash
          end

          def eql?(other)
            hash == other.hash
          end
        end

        class PresentedSeasonalMeasure
          attr_reader :goods_nomenclature_item_id,
                      :geographical_area_id,
                      :measure_type_id,
                      :from,
                      :to

          attr_accessor :failed_duty_status

          def initialize(row)
            @goods_nomenclature_item_id = row['goods_nomenclature_item_id']
            @geographical_area_id = row['geographical_area_id']
            @measure_type_id = row['measure_type_id']
            @from = row['from']
            @to = row['to']
          end

          def [](key)
            public_send(key)
          end

          def hash
            [
              goods_nomenclature_item_id,
              geographical_area_id,
              measure_type_id,
              validity_end_date.iso8601,
            ].hash
          end

          def eql?(other)
            hash == other.hash
          end

          def validity_start_date
            "#{from}/#{Time.zone.today.year}".to_date
          end

          def validity_end_date
            candidate_to = if to == '29/02' && !Time.zone.today.leap?
                             "28/02/#{Time.zone.today.year}"
                           elsif to == '28/02' && Time.zone.today.leap?
                             "29/02/#{Time.zone.today.year}"
                           else
                             "#{to}/#{Time.zone.today.year}"
                           end.to_date

            # Handle cases where the validity start date is after the validity end date
            # e.g start 01/10  end 30/04
            delta = candidate_to - validity_start_date

            if delta.negative?
              candidate_to + 1.year
            else
              candidate_to
            end
          end
        end
      end
    end
  end
end
