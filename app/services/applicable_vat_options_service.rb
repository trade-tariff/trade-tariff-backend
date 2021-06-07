class ApplicableVatOptionsService
  def initialize(measures)
    @measures = measures
  end

  def call
    measures.each_with_object({}) do |measure, acc|
      vat_key = measure.additional_code.present? ? "#{measure.additional_code.additional_code_type_id}#{measure.additional_code.additional_code}" : 'VAT'
      vat_duty_amount = measure.measure_components.first&.duty_amount
      vat_description = measure.additional_code_id.present? ? measure.additional_code.description : measure.measure_type.description
      vat_description = "#{vat_description} (#{vat_duty_amount})"

      acc[vat_key] = vat_description
    end
  end

  private

  def measures
    @measures.select(&:vat?)
  end
end
