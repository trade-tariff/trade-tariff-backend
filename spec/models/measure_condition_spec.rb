RSpec.describe MeasureCondition do
  subject(:measure_condition) { create :measure_condition }

  describe '#requirement' do
    context 'with document requirement' do
      subject(:measure_condition) do
        create :measure_condition,
               condition_code: 'L',
               component_sequence_number: 3,
               condition_duty_amount: nil,
               condition_monetary_unit_code: nil,
               condition_measurement_unit_code: nil,
               condition_measurement_unit_qualifier_code: nil,
               certificate_code: certificate.certificate_code,
               certificate_type_code: certificate.certificate_type_code
      end

      let(:certificate_type) do
        create :certificate_type, :with_description,
               description: 'FOO'
      end
      let(:certificate_description) do
        create :certificate_description, :with_period,
               certificate_type_code: certificate_type.certificate_type_code,
               description: 'BAR'
      end
      let(:certificate) do
        create :certificate,
               certificate_code: certificate_description.certificate_code,
               certificate_type_code: certificate_description.certificate_type_code
      end

      it { expect(measure_condition.requirement).to eq 'FOO: BAR' }
    end

    context 'with duty expression requirement' do
      subject(:measure_condition) do
        create :measure_condition,
               condition_code: 'L',
               component_sequence_number: 3,
               condition_duty_amount: 108.56,
               condition_monetary_unit_code: monetary_unit.monetary_unit_code,
               condition_measurement_unit_code: measurement_unit.measurement_unit_code,
               condition_measurement_unit_qualifier_code: nil,
               certificate_code: nil,
               certificate_type_code: nil
      end

      let(:monetary_unit) do
        create :monetary_unit, :with_description,
               monetary_unit_code: 'FOO'
      end
      let(:measurement_unit) do
        create :measurement_unit, :with_description,
               description: 'BAR'
      end

      it 'returns rendered requirement duty expression' do
        expect(measure_condition.requirement).to eq "<span>108.56</span> FOO / <abbr title='BAR'>BAR</abbr>"
      end
    end
  end

  describe '#document_code' do
    subject(:measure_condition) { create :measure_condition, condition_code: 'L', certificate_type_code: '1' }

    it 'contains certificate_type_code' do
      expect(measure_condition.document_code).to include(measure_condition.certificate_type_code)
    end

    it 'contains certificate_code' do
      expect(measure_condition.certificate_code).to include(measure_condition.certificate_code)
    end
  end

  describe '#action' do
    subject(:measure_condition) { create(:measure_condition, measure_action: create(:measure_action)) }

    before do
      allow(measure_condition.measure_action).to receive(:description).and_return('foo')
    end

    it { expect(measure_condition.action).to eq('foo') }
  end

  describe '#condition' do
    subject(:measure_condition) do
      create :measure_condition, condition_code: '123',
                                 component_sequence_number: 456
    end

    before do
      create :measure_condition_code, condition_code: measure_condition.condition_code
      create :measure_condition_code_description, condition_code: measure_condition.condition_code
    end

    it 'contains condition_code' do
      expect(measure_condition.condition).to include(measure_condition.condition_code)
    end

    it 'contains component_sequence_number' do
      expect(measure_condition.condition).not_to include(measure_condition.component_sequence_number.to_s)
    end

    it 'contains measure_condition_code_description' do
      expect(measure_condition.condition).to include(measure_condition.measure_condition_code_description.to_s)
    end
  end

  describe '#entry_price_system?' do
    subject(:measure_condition) { build :measure_condition, condition_code: }

    context 'when the condition code is for the entry price system' do
      let(:condition_code) { 'V' }

      it { is_expected.to be_entry_price_system }
    end

    context 'when the condition code is not for the entry price system' do
      let(:condition_code) { 'FOO' }

      it { is_expected.not_to be_entry_price_system }
    end
  end

  describe '#expresses_unit?' do
    context 'when the measure condition has condition units' do
      subject(:measure_condition) { create(:measure_condition, condition_measurement_unit_code: 'TNE') }

      it { is_expected.to be_expresses_unit }
    end

    context 'when the measure condition has no condition units' do
      subject(:measure_condition) { create(:measure_condition, condition_measurement_unit_code: nil) }

      it { is_expected.not_to be_expresses_unit }
    end
  end

  describe '#unit_for' do
    subject(:measure_condition) { create(:measure_condition, condition_measurement_unit_code:) }

    context 'when the measure condition has condition units and the measure is an excise measure' do
      let(:condition_measurement_unit_code) { 'TNE' }
      let(:measure) { create(:measure, :excise) }

      it { expect(measure_condition.unit_for(measure)).to include(measurement_unit_code: 'TNE') }
    end

    context 'when the measure condition no condition units and the measure is an excise measure' do
      let(:condition_measurement_unit_code) { nil }
      let(:measure) { create(:measure, :excise) }

      it { expect(measure_condition.unit_for(measure)).to be_nil }
    end

    context 'when the measure condition has condition units and the measure is not an excise measure' do
      let(:condition_measurement_unit_code) { 'TNE' }
      let(:measure) { create(:measure) }

      it { expect(measure_condition.unit_for(measure)).to be_nil }
    end
  end

  describe '#is_excluded_condition?' do
    context 'when the measure condition has a cds waiver document_code' do
      subject(:measure_condition) { create(:measure_condition, certificate_type_code: '9', certificate_code: '99L') }

      it { is_expected.to be_is_excluded_condition }
    end

    context 'when the measure condition has a negative action' do
      subject(:measure_condition) { create(:measure_condition, :negative) }

      it { is_expected.to be_is_excluded_condition }
    end

    context 'when the measure condition has a negative action and is an included explicitly negative action' do
      subject(:measure_condition) { create(:measure_condition, :negative, action_code: '08') }

      it { is_expected.not_to be_is_excluded_condition }
    end

    context 'when the measure condition has a negative action and has a document_code' do
      subject(:measure_condition) { create(:measure_condition, :negative, certificate_code: '999') }

      it { is_expected.not_to be_is_excluded_condition }
    end

    context 'when the measure condition has a negative action and is a threshold' do
      subject(:measure_condition) { create(:measure_condition, :negative, :threshold) }

      it { is_expected.not_to be_is_excluded_condition }
    end
  end

  describe '#universal_waiver_applies?' do
    context 'when the measure condition has a cds waiver document_code' do
      subject(:measure_condition) { create(:measure_condition, certificate_type_code: '9', certificate_code: '99L') }

      it { is_expected.to be_universal_waiver_applies }
    end

    context 'when the measure condition has no cds waiver document_code' do
      subject(:measure_condition) { create(:measure_condition, certificate_type_code: '7', certificate_code: '99L') }

      it { is_expected.not_to be_universal_waiver_applies }
    end
  end

  describe '#permutation_key' do
    subject { measure_condition.permutation_key }

    let(:type_code) { measure_condition.certificate_type_code }
    let(:certificate_code) { measure_condition.certificate_code }
    let(:duty_amount) { measure_condition.condition_duty_amount }

    it { is_expected.to eql "#{type_code}-#{certificate_code}-#{duty_amount}" }

    context 'with nil certificate_type_code' do
      let(:measure_condition) { create :measure_condition, certificate_type_code: nil }

      it { is_expected.to eql "-#{certificate_code}-#{duty_amount}" }
    end

    context 'with nil certificate_code' do
      let(:measure_condition) { create :measure_condition, certificate_code: nil }

      it { is_expected.to eql "#{type_code}--#{duty_amount}" }
    end

    context 'with nil condition_duty_amount' do
      let(:measure_condition) { create :measure_condition, condition_duty_amount: nil }

      it { is_expected.to eql "#{type_code}-#{certificate_code}-" }
    end

    context 'with nil certificate_code, certificate_type_code and condition_duty_amount' do
      let :measure_condition do
        create :measure_condition, certificate_type_code: nil,
                                   certificate_code: nil,
                                   condition_duty_amount: nil
      end

      it { is_expected.to eql measure_condition.measure_condition_sid }
    end
  end

  describe '#guidance_cds' do
    subject(:guidance_cds) { create(:measure_condition, :with_guidance).guidance_cds }

    it { is_expected.not_to be_nil }
  end

  describe '#threshold_unit_type' do
    context 'when the condition code is for the entry price system' do
      subject(:measure_condition) { build :measure_condition, :eps }

      it { expect(measure_condition.threshold_unit_type).to eq :eps }
    end

    context 'when the condition is price condition' do
      subject(:measure_condition) { build :measure_condition, :price }

      it { expect(measure_condition.threshold_unit_type).to eq :price }
    end

    context 'when the condition is weight condition' do
      subject(:measure_condition) { build :measure_condition, :weight }

      it { expect(measure_condition.threshold_unit_type).to eq :weight }
    end

    context 'when the condition is volume condition' do
      subject(:measure_condition) { build :measure_condition, :volume }

      it { expect(measure_condition.threshold_unit_type).to eq :volume }
    end

    context 'when the condition is percentage_abv condition' do
      subject(:measure_condition) { build :measure_condition, :percentage_abv }

      it { expect(measure_condition.threshold_unit_type).to eq :percentage_abv }
    end

    context 'when the condition is not threshold condition' do
      subject(:measure_condition) { build :measure_condition, :without_threshold }

      it { expect(measure_condition.threshold_unit_type).to be_nil }
    end
  end

  describe '#is_exempting_with_certificate_overridden?' do
    context 'when the condition is exemption class and certificate has not been overridden' do
      subject(:measure_condition) { create :measure_condition, certificate: }

      let(:certificate) { create(:certificate, certificate_code: '005', certificate_type_code: 'Y') }

      it { is_expected.to be_is_exempting_with_certificate_overridden }
    end

    context 'when the condition is exemption class and certificate has been overridden' do
      subject(:measure_condition) { create :measure_condition, certificate: }

      let(:certificate) { create(:certificate, certificate_code: '005', certificate_type_code: 'Y', exempting_certificate_override:) }
      let(:exempting_certificate_override) { create :exempting_certificate_override }

      it { is_expected.not_to be_is_exempting_with_certificate_overridden }
    end

    context 'when the condition is not exemption class and certificate has not been overridden' do
      subject(:measure_condition) { create :measure_condition, certificate: }

      let(:certificate) { create(:certificate, certificate_code: '005', certificate_type_code: 'C') }

      it { is_expected.not_to be_is_exempting_with_certificate_overridden }
    end

    context 'when the condition is not exemption class and certificate has been overridden' do
      subject(:measure_condition) { create :measure_condition, certificate: }

      let(:certificate) { create(:certificate, certificate_code: '005', certificate_type_code: 'C', exempting_certificate_override:) }
      let(:exempting_certificate_override) { create :exempting_certificate_override }

      it { is_expected.to be_is_exempting_with_certificate_overridden }
    end
  end
end
