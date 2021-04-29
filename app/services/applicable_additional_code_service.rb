class ApplicableAdditionalCodeService
  def initialize(measures)
    @measures = measures
  end

  def call
    applicable_measures.each_with_object({}) do |measure, acc|
      measure_type_id = measure.measure_type_id

      acc[measure_type_id] = {} if acc[measure_type_id].blank?
      acc[measure_type_id]['heading'] = heading_annotations_for(measure.additional_code.type)
      acc[measure_type_id]['additional_codes'] = [] if acc[measure_type_id]['additional_codes'].blank?
      acc[measure_type_id]['additional_codes'] << code_annotations_for(measure.additional_code)
    end
  end

  private

  def applicable_measures
    @measures.select { |measure| measure.additional_code&.applicable? }
  end

  def code_annotations_for(additional_code)
    overriding_annotation = AdditionalCode.additional_codes['code_overrides'][additional_code.code]

    return overriding_annotation if overriding_annotation.present?

    {
      'code' => additional_code.code,
      'overlay' => additional_code.description,
      'hint' => '',
    }
  end

  def heading_annotations_for(type)
    AdditionalCode.additional_codes['headings'][type]
  end
end
