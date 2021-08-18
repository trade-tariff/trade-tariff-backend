class AdditionalCode < Sequel::Model
  EXCISE_TYPE = 'excise'.freeze
  PREFERENCE_TYPE = 'preference'.freeze
  REMEDY_TYPE = 'remedy'.freeze
  UNKNOWN_TYPE = 'unknown'.freeze

  PREFERENCE_TYPE_IDS = %w[2].freeze
  REMEDY_TYPE_IDS = %w[8 A B C].freeze
  EXCISE_TYPE_IDS = %w[X].freeze

  plugin :time_machine
  plugin :oplog, primary_key: :additional_code_sid

  set_primary_key [:additional_code_sid]

  many_to_many :additional_code_descriptions,
               join_table: :additional_code_description_periods,
               left_primary_key: :additional_code_sid,
               left_key: :additional_code_sid,
               right_key: %i[additional_code_description_period_sid
                             additional_code_sid],
               right_primary_key: %i[additional_code_description_period_sid
                                     additional_code_sid] do |ds|
    ds.with_actual(AdditionalCodeDescriptionPeriod)
      .order(Sequel.desc(:additional_code_description_periods__validity_start_date))
  end

  one_to_many :measures, key: :additional_code_sid,
                         primary_key: :additional_code_sid

  def additional_code_description
    additional_code_descriptions.first
  end

  one_to_one :meursing_additional_code, key: :additional_code,
                                        primary_key: :additional_code

  one_to_one :export_refund_nomenclature, key: :export_refund_code,
                                          primary_key: :additional_code

  delegate :description, :formatted_description, to: :additional_code_description

  def code
    "#{additional_code_type_id}#{additional_code}"
  end

  def id
    additional_code_sid
  end

  def applicable?
    type != UNKNOWN_TYPE
  end

  def type
    return EXCISE_TYPE if additional_code_type_id.in?(EXCISE_TYPE_IDS)
    return PREFERENCE_TYPE if additional_code_type_id.in?(PREFERENCE_TYPE_IDS)
    return REMEDY_TYPE if additional_code_type_id.in?(REMEDY_TYPE_IDS)

    UNKNOWN_TYPE
  end

  def self.additional_codes
    @additional_codes ||=
      begin
        file = File.join(::Rails.root, 'db', 'additional_codes.json').freeze
        JSON.parse(File.read(file))
      end
  end
end
