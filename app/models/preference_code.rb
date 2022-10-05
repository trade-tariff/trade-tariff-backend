class PreferenceCode
  def initialize(id:, description:)
    @id = id
    @description = description
  end

  attr_accessor :id, :description

  class << self
    def find(commodity, measure)
      preference_code = preference_codes_for(measure.measure_type_id)

      return preference_code if preference_code.present?

      case measure.measure_type_id
      when '103'
        if commodity.authorised_use_provisions_submission?
          '140'
        elsif commodity.special_nature?
          '150'
        else
          '100'
        end
      when '112'
        measure.authorised_use? ? '115' : '110'
      when '122'
        if commodity.special_nature?
          '125'
        elsif measure.authorised_use?
          '123'
        else
          '120'
        end
      when '141'
        measure.authorised_use? ? '315' : '310'
      when '142'
        if measure.gsp?
          measure.authorised_use? ? '240' : '200'
        else
          measure.authorised_use? ? '340' : '300'
        end
      when '143'
        if measure.gsp?
          if commodity.special_nature?
            '255'
          elsif measure.authorised_use?
            '223'
          else
            '220'
          end
        elsif commodity.special_nature?
          '325'
        elsif measure.authorised_use?
          '323'
        else
          '320'
        end
      when '145'
        measure.gsp? ? '240' : '340'
      when '146'
        measure.gsp? ? '223' : '323'
      end
    end

    private

    def preference_codes_for(measure_type_id)
      {
        '105' => '140',
        '106' => '400',
        '115' => '115',
        '117' => '140',
        '119' => '119',
        '123' => '123',
      }[measure_type_id]
    end
  end
end
