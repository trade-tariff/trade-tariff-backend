class AdditionalCode < Sequel::Model
  EXCISE_TYPE = 'excise'.freeze
  PREFERENCE_TYPE = 'preference'.freeze
  REMEDY_TYPE = 'remedy'.freeze
  UNKNOWN_TYPE = 'unknown'.freeze

  MEURSING_TYPE_IDS = %w[7].freeze
  PREFERENCE_TYPE_IDS = %w[2].freeze
  REMEDY_TYPE_IDS = %w[8 A B C].freeze
  EXCISE_TYPE_IDS = %w[X].freeze

  plugin :time_machine
  plugin :oplog, primary_key: :additional_code_sid, materialized: true

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

  one_to_one :exempting_additional_code_override,
             class: 'ExemptingAdditionalCodeOverride',
             class_namespace: 'GreenLanes',
             primary_key: %i[additional_code_type_id additional_code],
             key: %i[additional_code_type_id additional_code]

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

  class << self
    def null_code
      OpenStruct.new(code: 'none', description: 'No additional code')
    end

    def heading_for(type)
      additional_codes.dig('headings', type)
    end

    def override_for(code)
      overrides_for(code).dup
    end

    private

    def overrides_for(code)
      additional_codes.dig('code_overrides', code) || {}
    end

    def additional_codes
      @additional_codes ||=
        begin
          file_path = Rails.root.join('db/additional_codes.json').freeze
          JSON.parse(File.read(file_path))
        end
    end
  end
end
