class PreferenceCode
  def initialize(code:, description:)
    @code = code
    @description = description
  end

  attr_accessor :code, :description

  alias_method :id, :code

  class << self
    MEASURE_TYPE_ID_PREFERENCE_CODE_MAPPING = Hash.new(->(_presented_declarable, _measure) {})
    MEASURE_TYPE_ID_PREFERENCE_CODE_MAPPING['105'] = ->(_, _) { '140' }
    MEASURE_TYPE_ID_PREFERENCE_CODE_MAPPING['106'] = ->(_, _) { '400' }
    MEASURE_TYPE_ID_PREFERENCE_CODE_MAPPING['115'] = ->(_, _) { '115' }
    MEASURE_TYPE_ID_PREFERENCE_CODE_MAPPING['117'] = ->(_, _) { '140' }
    MEASURE_TYPE_ID_PREFERENCE_CODE_MAPPING['119'] = ->(_, _) { '119' }
    MEASURE_TYPE_ID_PREFERENCE_CODE_MAPPING['123'] = ->(_, _) { '123' }
    MEASURE_TYPE_ID_PREFERENCE_CODE_MAPPING['103'] = lambda do |presented_declarable, measure|
      if presented_declarable.authorised_use_provisions_submission?
        '140'
      elsif presented_declarable.special_nature?(measure)
        '150'
      else
        '100'
      end
    end
    MEASURE_TYPE_ID_PREFERENCE_CODE_MAPPING['112'] = lambda do |_presented_declarable, measure|
      measure.authorised_use? ? '115' : '110'
    end
    MEASURE_TYPE_ID_PREFERENCE_CODE_MAPPING['122'] = lambda do |presented_declarable, measure|
      if presented_declarable.special_nature?(measure)
        '125'
      elsif measure.authorised_use?
        '123'
      else
        '120'
      end
    end
    MEASURE_TYPE_ID_PREFERENCE_CODE_MAPPING['141'] = lambda do |_presented_declarable, measure|
      measure.authorised_use? ? '315' : '310'
    end
    MEASURE_TYPE_ID_PREFERENCE_CODE_MAPPING['142'] = lambda do |_presented_declarable, measure|
      if measure.gsp_or_dcts?
        measure.authorised_use? ? '240' : '200'
      else
        measure.authorised_use? ? '340' : '300'
      end
    end
    MEASURE_TYPE_ID_PREFERENCE_CODE_MAPPING['143'] = lambda do |presented_declarable, measure|
      if measure.gsp_or_dcts?
        if presented_declarable.special_nature?(measure)
          '255'
        elsif measure.authorised_use?
          '223'
        else
          '220'
        end
      elsif presented_declarable.special_nature?(measure)
        '325'
      elsif measure.authorised_use?
        '323'
      else
        '320'
      end
    end
    MEASURE_TYPE_ID_PREFERENCE_CODE_MAPPING['145'] = lambda do |_presented_declarable, measure|
      measure.gsp_or_dcts? ? '240' : '340'
    end
    MEASURE_TYPE_ID_PREFERENCE_CODE_MAPPING['146'] = lambda do |_presented_declarable, measure|
      measure.gsp_or_dcts? ? '223' : '323'
    end
    MEASURE_TYPE_ID_PREFERENCE_CODE_MAPPING.freeze

    def determine_code(presented_declarable, presented_measure)
      MEASURE_TYPE_ID_PREFERENCE_CODE_MAPPING[presented_measure.measure_type_id].call(
        presented_declarable,
        presented_measure,
      )
    end

    delegate :[], to: :preference_codes

    def build(declarable, measure)
      determined_code = determine_code(declarable, measure)

      self[determined_code]
    end

    def all
      preference_codes.values
    end

    def preference_codes
      @preference_codes ||= codes_from_file.each_with_object({}) do |preference_code, acc|
        code = preference_code['id']
        description = preference_code['description']

        acc[code] = PreferenceCode.new(code:, description:)
      end
    end

    def codes_from_file
      JSON.load_file('data/preference_codes.json')
    end
  end
end
