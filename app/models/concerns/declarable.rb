module Declarable
  extend ActiveSupport::Concern
  include Formatter

  included do
    one_to_many :measures, primary_key: {}, key: {}, dataset: lambda {
      Measure.join(
        Measure.with_base_regulations
               .with_actual(BaseRegulation)
               .where({ measures__goods_nomenclature_sid: uptree.map(&:goods_nomenclature_sid) })
               .where { Sequel.~(measures__measure_type_id: MeasureType.excluded_measure_types) }
               .order(Sequel.desc(:measures__measure_generating_regulation_id), Sequel.desc(:measures__measure_type_id), Sequel.desc(:measures__goods_nomenclature_sid), Sequel.desc(:measures__geographical_area_id), Sequel.desc(:measures__geographical_area_sid), Sequel.desc(:measures__additional_code_type_id), Sequel.desc(:measures__additional_code_id), Sequel.desc(:measures__ordernumber), Sequel.desc(:effective_start_date))
               .tap! { |query|
                 if export_refund_uptree.present?
                   query.union(
                     Measure.with_base_regulations
                       .with_actual(BaseRegulation)
                       .where({ measures__export_refund_nomenclature_sid: export_refund_uptree.map(&:export_refund_nomenclature_sid) })
                       .where { Sequel.~(measures__measure_type_id: MeasureType.excluded_measure_types) }
                       .order(Sequel.desc(:measures__measure_generating_regulation_id), Sequel.desc(:measures__measure_type_id), Sequel.desc(:measures__goods_nomenclature_sid), Sequel.desc(:measures__geographical_area_id), Sequel.desc(:measures__geographical_area_sid), Sequel.desc(:measures__additional_code_type_id), Sequel.desc(:measures__additional_code_id), Sequel.desc(:measures__ordernumber), Sequel.desc(:effective_start_date)),
                   )
                 end
               }
       .union(
         Measure.with_modification_regulations
                .with_actual(ModificationRegulation)
                .where({ measures__goods_nomenclature_sid: uptree.map(&:goods_nomenclature_sid) })
                .where { Sequel.~(measures__measure_type_id: MeasureType.excluded_measure_types) }
                .order(Sequel.desc(:measures__measure_generating_regulation_id), Sequel.desc(:measures__measure_type_id), Sequel.desc(:measures__goods_nomenclature_sid), Sequel.desc(:measures__geographical_area_id), Sequel.desc(:measures__geographical_area_sid), Sequel.desc(:measures__additional_code_type_id), Sequel.desc(:measures__additional_code_id), Sequel.desc(:measures__ordernumber), Sequel.desc(:effective_start_date))
                .tap! do |query|
                  if export_refund_uptree.present?
                    query.union(
                      Measure.with_modification_regulations
                             .with_actual(ModificationRegulation)
                             .where({ measures__export_refund_nomenclature_sid: export_refund_uptree.map(&:export_refund_nomenclature_sid) })
                             .where { Sequel.~(measures__measure_type_id: MeasureType.excluded_measure_types) }
                             .order(Sequel.desc(:measures__measure_generating_regulation_id), Sequel.desc(:measures__measure_type_id), Sequel.desc(:measures__goods_nomenclature_sid), Sequel.desc(:measures__geographical_area_id), Sequel.desc(:measures__geographical_area_sid), Sequel.desc(:measures__additional_code_type_id), Sequel.desc(:measures__additional_code_id), Sequel.desc(:measures__ordernumber), Sequel.desc(:effective_start_date)),
                    )
                  end
                end,
         alias: :measures,
       )
       .with_actual(Measure)
       .order(Sequel.asc(:measures__geographical_area_id),
              Sequel.asc(:measures__measure_type_id),
              Sequel.asc(:measures__additional_code_type_id),
              Sequel.asc(:measures__additional_code_id),
              Sequel.asc(:measures__ordernumber),
              Sequel.desc(:effective_start_date)),
        t1__measure_sid: :measures__measure_sid,
      )
    }

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

  def export_refund_uptree
    @export_refund_uptree ||= export_refund_nomenclatures.map(&:uptree).flatten
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
end
