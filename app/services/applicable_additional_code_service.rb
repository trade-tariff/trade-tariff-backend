class ApplicableAdditionalCodeService
  def initialize(measures)
    @measures = measures
  end

  def call
    applicable_additional_codes.tap do |codes|
      codes.each_key do |measure_type_id|
        none_option_additional_code_measure = measure_no_additional_codes_for(measure_type_id)

        if none_option_additional_code_measure.present?
          codes[measure_type_id]['additional_codes'] << code_annotations_for(none_option_additional_code_measure)
        end
      end
    end
  end

  private

  def applicable_additional_codes
    unique_applicable_measures.each_with_object({}) do |measure, acc|
      measure_type_id = measure.measure_type_id

      acc[measure_type_id] = {} if acc[measure_type_id].blank?
      acc[measure_type_id]['measure_type_description'] = measure&.measure_type&.description
      acc[measure_type_id]['heading'] = heading_annotations_for(measure.additional_code.type)
      acc[measure_type_id]['additional_codes'] = [] if acc[measure_type_id]['additional_codes'].blank?
      acc[measure_type_id]['additional_codes'] << code_annotations_for(measure)
    end
  end

  def measure_no_additional_codes_for(measure_type_id)
    @measures.find do |measure|
      measure.measure_type_id == measure_type_id && measure.additional_code.blank?
    end
  end

  def unique_applicable_measures
    applicable_measures.uniq(&:measure_sid)
  end

  def applicable_measures
    @measures.select { |measure| measure.additional_code&.applicable? }
  end

  def code_annotations_for(measure)
    additional_code = measure.additional_code.presence || AdditionalCode.null_code
    overriding_annotation = AdditionalCode.additional_codes['code_overrides'][additional_code.code]

    if overriding_annotation.present?
      overriding_annotation['measure_sid'] = measure.measure_sid
      overriding_annotation
    else
      {
        'code' => additional_code.code,
        'overlay' => additional_code.description,
        'hint' => '',
        'measure_sid' => measure.measure_sid,
      }
    end
  end

  def heading_annotations_for(type)
    AdditionalCode.additional_codes['headings'][type]
  end
end
