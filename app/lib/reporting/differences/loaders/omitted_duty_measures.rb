module Reporting
  class Differences
    class Loaders
      class OmittedDutyMeasures
        include Reporting::Differences::Loaders::Helpers

        delegate                  :each_chapter,
                                  to: :report

        INCLUDED_MEASURE_TYPES = Set.new(
          %w[
            112
            115
            117
            119
            142
            143
            145
            146
          ],
        )

        EXCLUDED_GEOGRAPHICAL_AREA_IDS = Set.new(
          %w[
            1080
            2005
            2020
            2027
            UA
          ],
        ).freeze

        def data
          rows = []
          each_row do |row|
            rows << row
          end
          rows
        end

        private

        def each_row
          start_time = Time.zone.now
          non_continuous_measures = Set.new

          past_declarables_and_measures.each do |declarable, past_measures|
            current_measures = current_declarables_and_measures[declarable]

            next if current_measures.nil?

            # rubocop:disable Style/HashEachMethods
            past_measures.each do |past_measure, _|
              non_continuous_measures << past_measure unless current_measures.include?(past_measure)
            end
            # rubocop:enable Style/HashEachMethods
          end

          non_continuous_measures.each { |measure| yield build_row_for(measure) }

          end_time = Time.zone.now
          Rails.logger.debug("Time taken for each_row: #{end_time - start_time} seconds")
        end

        def current_declarables_and_measures
          @current_declarables_and_measures ||= begin
            start_time = Time.zone.now
            acc = {}

            as_of = Time.zone.today.iso8601
            Rails.logger.debug("Processing current_declarables_and_measures for date: #{as_of}")

            each_declarable(as_of) do |declarable|
              declarable.applicable_measures.each do |measure|
                measure = PresentedMeasure.new(measure)

                next unless INCLUDED_MEASURE_TYPES.include?(measure.measure_type_id)
                next if EXCLUDED_GEOGRAPHICAL_AREA_IDS.include?(measure.geographical_area_id)

                acc[declarable] ||= Set.new
                acc[declarable] << measure
              end
            end

            end_time = Time.zone.now
            Rails.logger.debug("Time taken for current_declarables_and_measures: #{end_time - start_time} seconds")

            acc
          end
        end

        def past_declarables_and_measures
          @past_declarables_and_measures ||= begin
            start_time = Time.zone.now
            acc = {}

            as_of = (Time.zone.today - 1.year).iso8601
            Rails.logger.debug("Processing past_declarables_and_measures for date: #{as_of}")

            each_declarable(as_of) do |declarable|
              declarable.applicable_measures.each do |measure|
                measure = PresentedMeasure.new(measure)

                next unless INCLUDED_MEASURE_TYPES.include?(measure.measure_type_id)
                next if EXCLUDED_GEOGRAPHICAL_AREA_IDS.include?(measure.geographical_area_id)

                acc[declarable] ||= Set.new
                acc[declarable] << measure
              end
            end
            end_time = Time.zone.now
            Rails.logger.debug("Time taken for past_declarables_and_measures: #{end_time - start_time} seconds")

            acc
          end
        end

        def each_declarable(as_of)
          start_time = Time.zone.now
          each_chapter(eager: Differences::GOODS_NOMENCLATURE_MEASURE_EAGER, as_of:) do |eager_chapter|
            eager_chapter.descendants.each do |chapter_descendant|
              next unless chapter_descendant.declarable?

              yield PresentedDeclarable.new(chapter_descendant)
            end
          end
          end_time = Time.zone.now
          Rails.logger.debug("Time taken for each_declarable: #{end_time - start_time} seconds")
        end

        def build_row_for(measure)
          [
            measure.goods_nomenclature_item_id,
            measure.geographical_area_id,
            measure.measure_type_id,
            measure.effective_start_date.strftime('%d/%m'),
            measure.ordernumber,
            measure.additional_code,
          ]
        end

        class PresentedDeclarable < WrapDelegator
          def hash
            @hash ||= [
              goods_nomenclature_item_id,
              producline_suffix,
            ].hash
          end

          def eql?(other)
            hash == other.hash
          end
        end

        class PresentedMeasure < WrapDelegator
          def hash
            @hash ||= [
              goods_nomenclature_item_id,
              geographical_area_id,
              measure_type_id,
              ordernumber,
              additional_code,
            ].hash
          end

          def eql?(other)
            hash == other.hash
          end

          def additional_code
            "#{additional_code_type_id}#{additional_code_id}".presence || nil
          end
        end
      end
    end
  end
end
