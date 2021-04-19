require 'rails_helper'

describe MeasureCondition do
  describe 'associations' do
    describe 'monetary unit' do
      it_is_associated 'one to one to', :monetary_unit do
        let!(:left_primary_key) { :condition_monetary_unit_code }
        let!(:monetary_unit_code) { Forgery(:basic).text(exactly: 3) }
        let!(:condition_monetary_unit_code) { monetary_unit_code }
      end
    end

    describe 'measurement unit' do
      it_is_associated 'one to one to', :measurement_unit do
        let!(:left_primary_key) { :condition_measurement_unit_code }
        let!(:measurement_unit_code) { Forgery(:basic).text(exactly: 3) }
        let!(:condition_measurement_unit_code) { measurement_unit_code }
      end
    end

    describe 'measurement unit qualifier' do
      it_is_associated 'one to one to', :measurement_unit_qualifier do
        let!(:left_primary_key) { :condition_measurement_unit_qualifier_code }
        let!(:measurement_unit_qualifier_code) { Forgery(:basic).text(exactly: 1) }
        let!(:condition_measurement_unit_qualifier_code) { measurement_unit_qualifier_code }
      end
    end

    describe 'measure condition code' do
      it_is_associated 'one to one to', :measure_condition_code do
        let!(:condition_code) { Forgery(:basic).text(exactly: 1) }
      end
    end

    describe 'measure action' do
      it_is_associated 'one to one to', :measure_action do
        let!(:action_code) { Forgery(:basic).text(exactly: 1) }
      end
    end

    describe 'certificate type' do
      it_is_associated 'one to one to', :certificate_type do
        let!(:certificate_type_code) { Forgery(:basic).text(exactly: 1) }
      end
    end

    describe 'certificate' do
      it_is_associated 'one to one to', :certificate do
        let!(:certificate_code) { Forgery(:basic).text(exactly: 3) }
        let!(:certificate_type_code) { Forgery(:basic).text(exactly: 1) }
      end
    end

    describe 'measure condition components' do
      let!(:measure_condition)                { create :measure_condition }
      let!(:measure_condition_component1)     { create :measure_condition_component, measure_condition_sid: measure_condition.measure_condition_sid }
      let!(:measure_condition_component2)     { create :measure_condition_component, measure_condition_sid: generate(:measure_condition_sid) }

      context 'direct loading' do
        it 'loads associated measure condition components' do
          expect(
            measure_condition.measure_condition_components,
          ).to include measure_condition_component1
        end

        it 'does not load associated measure component' do
          expect(
            measure_condition.measure_condition_components,
          ).not_to include measure_condition_component2
        end
      end

      context 'eager loading' do
        it 'loads associated measure components' do
          expect(
            described_class.where(measure_condition_sid: measure_condition.measure_condition_sid)
                 .eager(:measure_condition_components)
                 .all
                 .first
                 .measure_condition_components,
          ).to include measure_condition_component1
        end

        it 'does not load associated measure component' do
          expect(
            described_class.where(measure_condition_sid: measure_condition.measure_condition_sid)
                 .eager(:measure_condition_components)
                 .all
                 .first
                 .measure_condition_components,
          ).not_to include measure_condition_component2
        end
      end
    end
  end

  describe '#requirement' do
    context 'with document requirement' do
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
      let(:measure_condition) do
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

      it 'returns requirement certificate type and description' do
        expect(measure_condition.requirement).to eq 'FOO: BAR'
      end
    end

    context 'with duty expression requirement' do
      let(:monetary_unit) do
        create :monetary_unit, :with_description,
               monetary_unit_code: 'FOO'
      end
      let(:measurement_unit) do
        create :measurement_unit, :with_description,
               description: 'BAR'
      end

      let(:measure_condition) do
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

      it 'returns rendered requirement duty expression' do
        expect(measure_condition.requirement).to eq "<span>108.56</span> FOO / <abbr title='BAR'>BAR</abbr>"
      end
    end
  end

  describe '#document_code' do
    let(:measure_condition) { create :measure_condition, condition_code: 'L', certificate_type_code: '1' }

    it 'contains certificate_type_code' do
      expect(measure_condition.document_code).to include(measure_condition.certificate_type_code)
    end

    it 'contains certificate_code' do
      expect(measure_condition.certificate_code).to include(measure_condition.certificate_code)
    end
  end

  describe '#action' do
    let(:measure_condition) { create :measure_condition, measure_action: create(:measure_action) }

    it 'returns measure_action_description' do
      expect(measure_condition.measure_action).to receive(:description).at_least(1)
      expect(measure_condition.action).to eq(measure_condition.measure_action_description)
    end
  end

  describe '#condition' do
    let(:measure_condition) do
      create :measure_condition, condition_code: '123',
                                 component_sequence_number: 456
    end
    let!(:measure_condition_code) { create :measure_condition_code, condition_code: measure_condition.condition_code }
    let!(:measure_condition_code_description) { create :measure_condition_code_description, condition_code: measure_condition.condition_code }

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
    subject(:measure_condition) { build :measure_condition, condition_code: condition_code }

    context 'when the condition code is for the entry price system' do
      let(:condition_code) { 'V' }

      it { is_expected.to be_entry_price_system }
    end

    context 'when the condition code is not for the entry price system' do
      let(:condition_code) { 'FOO' }

      it { is_expected.not_to be_entry_price_system }
    end
  end
end
