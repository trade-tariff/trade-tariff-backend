# National Measure Type ID mapping
# A B C D E F G H I J
# 1 2 3 4 5 6 7 8 9 0

class MeasureType < Sequel::Model
  IMPORT_MOVEMENT_CODES = [0, 2].freeze
  EXPORT_MOVEMENT_CODES = [1, 2].freeze
  THIRD_COUNTRY = %w[103 105].freeze # 105 measure types are for end use Third Country duties. 103 are for everything else
  VAT_TYPES = %w[305 VTS].freeze
  SUPPLEMENTARY_TYPES = %w[109 110 111].freeze
  QUOTA_TYPES = %w[046 122 123 143 146 147 653 654].freeze
  NATIONAL_PR_TYPES = %w[AHC AIL ATT CEX CHM COE COI CVD DPO ECM EHC EQC EWP HOP HSE IWP PHC PRE PRT QRC SFS].freeze
  DEFAULT_EXCLUDED_TYPES = %w[442 447 SPL].freeze
  XI_EXCLUDED_TYPES = DEFAULT_EXCLUDED_TYPES + NATIONAL_PR_TYPES + QUOTA_TYPES
  GL_EXCLUDED_TYPES = DEFAULT_EXCLUDED_TYPES + NATIONAL_PR_TYPES
  UK_EXCLUDED_TYPES = DEFAULT_EXCLUDED_TYPES

  AUTHORISED_USE_PROVISIONS_SUBMISSION = '464'.freeze
  TARIFF_PREFERENCE = %w[142 145].freeze
  PREFERENTIAL_QUOTA = %w[143 146].freeze

  DEFENSE_MEASURES = [
    '551', # Provisional anti-dumping duty
    '552', # Definitive anti-dumping duty
    '553', # Provisional countervailing duty
    '554', # Definitive countervailing duty
    '555', # Anti-dumping/countervailing duty - Pending collection
    '695', # Additional duties - these are the retaliatory duties
    '696', # Additional duties (safeguard)
  ].freeze

  MEURSING_MEASURES = [
    '672', # Amount of additional duty on flour (shortened to ADSZ [Sucre Zucker])
    '673', # Amount of additional duty on sugar (shortened to ADFM [Farine Mehl])
    '674', # Agricultural component (shortened to EA {Élément agricole])
  ].freeze

  RULES_OF_ORIGIN_MEASURES = %w[
    142
    143
    145
    146
  ].freeze

  UNIT_EXPRESSABLE_MEASURES = [
    'C', # Applicable duty
    'D', # Anti-dumping/countervailing measures
    'J', # Countervailing charge
    'Q', # Excise
  ].freeze

  UNIT_EXPRESSABLE_MEASURES.freeze

  plugin :time_machine
  plugin :oplog, primary_key: :measure_type_id

  set_primary_key [:measure_type_id]

  one_to_one :measure_type_description, key: :measure_type_id,
                                        foreign_key: :measure_type_id

  one_to_many :measures, key: :measure_type_id,
                         foreign_key: :measure_type_id

  many_to_one :measure_type_series

  many_to_one :measure_type_series_description, key: :measure_type_series_id

  one_to_many :green_lanes_category_assessments, class: :'GreenLanes::CategoryAssessment'

  delegate :description, to: :measure_type_description

  dataset_module do
    def national
      where(national: true)
    end
  end

  def id
    measure_type_id
  end

  def third_country?
    measure_type_id.in?(THIRD_COUNTRY)
  end

  def supplementary?
    measure_type_id.in?(SUPPLEMENTARY_TYPES)
  end

  def trade_remedy?
    measure_type_id.in?(DEFENSE_MEASURES)
  end

  def expresses_unit?
    measure_type_series_id.in?(UNIT_EXPRESSABLE_MEASURES)
  end

  def excise?
    measure_type_series_id == 'Q'
  end

  def meursing?
    measure_type_id.in?(MEURSING_MEASURES)
  end

  def tariff_preference?
    measure_type_id.in?(TARIFF_PREFERENCE)
  end

  def preferential_quota?
    measure_type_id.in?(PREFERENTIAL_QUOTA)
  end

  # The VAT standard rate has measure type 305 and no additional code.
  # The VAT zero rate has measure type 305 and  VATZ additional code.
  # The VAT exempt has measure type 305 and  VATE additional code.
  # The VAT reduced rate 5% has measure type 305 and  VATA additional code.
  def vat?
    MeasureType::VAT_TYPES.include?(measure_type_id)
  end

  def rules_of_origin_apply?
    measure_type_id.in?(RULES_OF_ORIGIN_MEASURES)
  end

  def authorised_use_provisions_submission?
    measure_type_id.in?(AUTHORISED_USE_PROVISIONS_SUBMISSION)
  end

  def self.excluded_measure_types
    if TradeTariffBackend.xi?
      if TradeTariffRequest.green_lanes
        GL_EXCLUDED_TYPES
      else
        XI_EXCLUDED_TYPES
      end
    else
      UK_EXCLUDED_TYPES
    end
  end
end
