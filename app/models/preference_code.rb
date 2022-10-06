class PreferenceCode
  def initialize(id:, description:)
    @id = id
    @description = description
  end

  attr_accessor :id, :description

  # use methods to encapsulate each measure type id
  # use hash to lookup the measure type id and apply a lambda
  class << self
    MEASURE_TYPE_ID_PREFERENCE_CODE_MAPPING = Hash.new(->(_presented_declarable, _measure) {})
    MEASURE_TYPE_ID_PREFERENCE_CODE_MAPPING['105'] = ->(_, _) { '140' }
    MEASURE_TYPE_ID_PREFERENCE_CODE_MAPPING['106'] = ->(_, _) { '400' }
    MEASURE_TYPE_ID_PREFERENCE_CODE_MAPPING['115'] = ->(_, _) { '115' }
    MEASURE_TYPE_ID_PREFERENCE_CODE_MAPPING['117'] = ->(_, _) { '140' }
    MEASURE_TYPE_ID_PREFERENCE_CODE_MAPPING['119'] = ->(_, _) { '119' }
    MEASURE_TYPE_ID_PREFERENCE_CODE_MAPPING['123'] = ->(_, _) { '123' }
    MEASURE_TYPE_ID_PREFERENCE_CODE_MAPPING['103'] = lambda do |presented_declarable, _measure|
      if presented_declarable.authorised_use_provisions_submission?
        '140'
      elsif presented_declarable.special_nature?
        '150'
      else
        '100'
      end
    end
    MEASURE_TYPE_ID_PREFERENCE_CODE_MAPPING['112'] = lambda do |_presented_declarable, measure|
      measure.authorised_use? ? '115' : '110'
    end
    MEASURE_TYPE_ID_PREFERENCE_CODE_MAPPING['122'] = lambda do |presented_declarable, measure|
      if presented_declarable.special_nature?
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
      if measure.gsp?
        measure.authorised_use? ? '240' : '200'
      else
        measure.authorised_use? ? '340' : '300'
      end
    end
    MEASURE_TYPE_ID_PREFERENCE_CODE_MAPPING['143'] = lambda do |presented_declarable, measure|
      if measure.gsp?
        if presented_declarable.special_nature?
          '255'
        elsif measure.authorised_use?
          '223'
        else
          '220'
        end
      elsif presented_declarable.special_nature?
        '325'
      elsif measure.authorised_use?
        '323'
      else
        '320'
      end
    end
    MEASURE_TYPE_ID_PREFERENCE_CODE_MAPPING['145'] = lambda do |_presented_declarable, measure|
      measure.gsp? ? '240' : '340'
    end
    MEASURE_TYPE_ID_PREFERENCE_CODE_MAPPING['146'] = lambda do |_presented_declarable, measure|
      measure.gsp? ? '223' : '323'
    end
    MEASURE_TYPE_ID_PREFERENCE_CODE_MAPPING.freeze

    def find(presented_declarable, presented_measure)
      MEASURE_TYPE_ID_PREFERENCE_CODE_MAPPING[presented_measure.measure_type_id].try(
        :call,
        presented_declarable,
        presented_measure,
      )
    end
  end
end
