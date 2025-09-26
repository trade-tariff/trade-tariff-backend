class Certificate < Sequel::Model
  AUTHORISED_USE_ID = 'N990'.freeze
  SPECIAL_NATURE_TYPE_CODE = 'A'.freeze

  plugin :oplog, primary_key: %i[certificate_code certificate_type_code]
  plugin :time_machine

  set_primary_key %i[certificate_code certificate_type_code]

  many_to_many :certificate_descriptions, join_table: :certificate_description_periods,
                                          left_key: %i[certificate_code certificate_type_code],
                                          use_optimized: false,
                                          right_key: :certificate_description_period_sid do |ds|
    ds.with_actual(CertificateDescriptionPeriod)
      .order(Sequel.desc(:certificate_description_periods__validity_start_date))
  end

  one_to_one :appendix_5a,
             key: %i[certificate_type_code certificate_code],
             primary_key: %i[certificate_type_code certificate_code]

  one_to_many :certificate_description_periods, key: %i[certificate_code certificate_type_code] do |ds|
    ds.with_actual(CertificateDescriptionPeriod)
      .order(Sequel.desc(:certificate_description_periods__validity_start_date))
  end

  many_to_one :certificate_type_description, key: :certificate_type_code

  one_to_many :measure_conditions, key: %i[certificate_type_code certificate_code],
                                   primary_key: %i[certificate_type_code certificate_code]

  many_to_many :measures, join_table: :measure_conditions,
                          left_key: %i[certificate_code certificate_type_code],
                          right_key: :measure_sid,
                          use_optimized: false

  one_to_many :certificate_types, key: :certificate_type_code,
                                  primary_key: :certificate_type_code do |ds|
    ds.with_actual(CertificateType)
  end

  one_to_one :exempting_certificate_override,
             class: 'ExemptingCertificateOverride',
             class_namespace: 'GreenLanes',
             primary_key: %i[certificate_type_code certificate_code],
             key: %i[certificate_type_code certificate_code]

  def special_nature?
    certificate_type_code.in?(SPECIAL_NATURE_TYPE_CODE)
  end

  def authorised_use?
    id.in?(AUTHORISED_USE_ID)
  end

  def certificate_description
    certificate_descriptions.first
  end

  def certificate_description_period
    certificate_description_periods.first
  end

  def certificate_type
    certificate_types.first
  end

  def id
    "#{certificate_type_code}#{certificate_code}"
  end

  delegate :description, :formatted_description, to: :certificate_description
  delegate :guidance_cds, to: :appendix_5a, allow_nil: true

  dataset_module do
    def with_certificate_types_and_codes(certificate_types_and_codes)
      return self if certificate_types_and_codes.none?

      conditions = certificate_types_and_codes.map do |type, code|
        Sequel.expr(certificate_type_code: type) & Sequel.expr(certificate_code: code)
      end
      combined_conditions = conditions.reduce(:|)

      where(combined_conditions)
    end
  end
end
