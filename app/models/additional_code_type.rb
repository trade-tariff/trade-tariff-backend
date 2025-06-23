class AdditionalCodeType < Sequel::Model
  plugin :oplog, primary_key: :additional_code_type_id, materialized: true

  set_primary_key [:additional_code_type_id]

  one_to_many :additional_codes, key: :additional_code_type_id
  one_to_one  :additional_code_type_description, key: :additional_code_type_id
  one_to_many :additional_code_descriptions, key: :additional_code_type_id
  one_to_many :additional_code_type_measure_types
  many_to_many :measure_types, join_table: :additional_code_type_measure_types
  one_to_many :additional_code_description_periods, key: :additional_code_type_id
  one_to_many :footnote_association_additional_codes, key: :additional_code_type_id
  many_to_many :footnotes, join_table: :footnote_association_additional_codes,
                           class_name: 'Footnote'
  one_to_many :export_refund_nomenclatures, primary_key: :additional_code_type_id,
                                            key: :additional_code_type

  many_to_one :meursing_table_plan

  delegate :present?, to: :meursing_table_plan, prefix: true, allow_nil: true
  delegate :description, to: :additional_code_type_description

  APPLICATION_CODES = {
    0 => 'Export refund nomencalture',
    1 => 'Additional Codes',
    3 => 'Meursing addition codes',
    4 => 'Export refund for processed agricultural goods',
  }.freeze

  class << self
    def refresh!(concurrently: false)
      db.refresh_view(:additional_code_types, concurrently:)
    end
  end

  def meursing?
    application_code.in?('3')
  end

  def non_meursing?
    !meursing?
  end

  def export_refund?
    application_code == '0'
  end

  def export_refund_agricultural?
    application_code == '4'
  end
end
