RSpec.describe ApplicableVatOptionsService do
  subject(:service) { described_class.new(measures) }

  describe '#call' do
    context 'when the measures include vat measures' do
      let(:measures) do
        [
          non_vat_measure,
          vat_measure,
          vat_measure_with_additional_code,
        ]
      end
      let(:non_vat_measure) do
        create(
          :measure,
          :with_measure_type,
          measure_type_id: '105',
        )
      end
      let(:vat_measure) do
        create(
          :measure,
          :with_measure_type,
          :with_measure_components,
          measure_type_description: 'Value added tax',
          measure_type_id: '305',
          duty_amount: 20,
        )
      end
      let(:vat_measure_with_additional_code) do
        create(
          :measure,
          :with_additional_code,
          :with_measure_type,
          :with_measure_components,
          measure_type_description: 'Value added tax',
          measure_type_id: '305',
          additional_code_description: 'VAT zero rate',
          additional_code_type_id: 'V',
          additional_code: 'ATZ',
          duty_amount: 0,
        )
      end

      let(:expected) do
        {
          'VAT' => 'Value added tax (20.0%)',
          'VATZ' => 'VAT zero rate',
        }
      end

      it { expect(service.call).to eq(expected) }
    end

    context 'when the measures do not include vat measures' do
      let(:measures) { [non_vat_measure] }
      let(:non_vat_measure) do
        create(
          :measure,
          :with_measure_type,
          measure_type_id: '105',
        )
      end

      it { expect(service.call).to eq({}) }
    end
  end
end
