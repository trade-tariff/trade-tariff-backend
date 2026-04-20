require 'rails_helper'

RSpec.describe FactoryBot do
  describe 'shared factory sequences' do
    let(:shared_sequence_names) do
      %i[
        additional_code_description_period_sid
        additional_code_sid
        additional_code_type_id
        base_regulation_sid
        certificate_sid
        certificate_type_code
        condition_code
        export_refund_nomenclature_sid
        footnote_sid
        geographical_area_id
        geographical_area_sid
        goods_nomenclature_sid
        language_id
        measure_condition_sid
        measure_sid
        measure_type_id
        measure_type_series_id
        measurement_unit_code
        measurement_unit_qualifier_code
        modification_regulation_sid
        monetary_exchange_sid
        quota_definition_sid
        quota_order_number_sid
      ]
    end

    it 'defines shared sequences only in shared_sequences_factory' do
      offenders = Dir.glob(Rails.root.join('spec/factories/*.rb')).filter_map do |path|
        next if path.end_with?('shared_sequences_factory.rb')

        content = File.read(path)
        names = shared_sequence_names.select { |name| content.match?(/sequence\(\s*:#{name}\b/) }
        next if names.empty?

        [path.delete_prefix("#{Rails.root}/"), names]
      end

      expect(offenders).to eq([]), <<~MESSAGE
        Expected shared sequences to be defined only in spec/factories/shared_sequences_factory.rb.
        Found duplicates in:
        #{offenders.map { |path, names| "- #{path}: #{names.join(', ')}" }.join("\n")}
      MESSAGE
    end
  end
end
