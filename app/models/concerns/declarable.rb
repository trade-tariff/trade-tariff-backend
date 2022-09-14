module Declarable
  extend ActiveSupport::Concern
  include Formatter

  included do
    # TODO: Move uptree enumeration into materialized view
    one_to_many :measures, primary_key: {}, key: {} do |_ds|
      Measure.actual
        .where(goods_nomenclature_sid: uptree.map(&:goods_nomenclature_sid))
        .exclude(measure_type_id: MeasureType.excluded_measure_types)
    end

    one_to_many :import_measures, key: {}, primary_key: {}, dataset: lambda {
      measures_dataset.join(:measure_types, measure_types__measure_type_id: :measures__measure_type_id)
                      .filter(measure_types__trade_movement_code: MeasureType::IMPORT_MOVEMENT_CODES)
    }, class_name: 'Measure'

    one_to_many :export_measures, key: {}, primary_key: {}, dataset: lambda {
      measures_dataset.join(:measure_types, measure_types__measure_type_id: :measures__measure_type_id)
                      .filter(measure_types__trade_movement_code: MeasureType::EXPORT_MOVEMENT_CODES)
    }, class_name: 'Measure'

    one_to_many :basic_duty_rate_components, primary_key: {}, key: {}, class_name: 'MeasureComponent', dataset: lambda {
      MeasureComponent.where(measure: import_measures_dataset.where(measures__measure_type_id: MeasureType::THIRD_COUNTRY).all)
    }

    custom_format :description_plain, with: DescriptionTrimFormatter,
                                      using: :description
    custom_format :formatted_description, with: DescriptionFormatter,
                                          using: :description
  end

  def chapter_id
    "#{goods_nomenclature_item_id.first(2)}00000000"
  end

  def consigned?
    !!(description =~ /consigned from/i)
  end

  def consigned_from
    description.scan(/consigned from ([a-zA-Z,' ]+)(?:\W|$)/i).join(', ') if consigned?
  end

  def basic_duty_rate
    if basic_duty_rate_components.count == 1
      basic_duty_rate_components.map(&:formatted_duty_expression).join(' ')
    end
  end

  def meursing_code?
    measures.any?(&:meursing?)
  end
  alias_method :meursing_code, :meursing_code?

  def import_trade_summary
    ImportTradeSummary.build(import_measures)
  end

  delegate :id, to: :import_trade_summary, prefix: true
end
