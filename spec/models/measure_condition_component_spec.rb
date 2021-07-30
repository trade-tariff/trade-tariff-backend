require 'rails_helper'

describe MeasureConditionComponent do
  describe 'associations' do
    describe 'duty expression' do
      it_is_associated 'one to one to', :duty_expression do
        let(:duty_expression_id) { Forgery(:basic).text(exactly: 3) }
      end
    end

    describe 'measurement unit' do
      it_is_associated 'one to one to', :measurement_unit do
        let(:measurement_unit_code) { Forgery(:basic).text(exactly: 3) }
      end
    end

    describe 'monetary unit' do
      it_is_associated 'one to one to', :monetary_unit do
        let(:monetary_unit_code) { Forgery(:basic).text(exactly: 3) }
      end
    end

    describe 'measurement unit qualifier' do
      it_is_associated 'one to one to', :measurement_unit_qualifier do
        let(:measurement_unit_qualifier_code) { Forgery(:basic).text(exactly: 1) }
      end
    end
  end

  describe '#ad_valorem?' do
    context 'when the measure condition component is an ad valorum component' do
      subject(:measure_condition_component) { create(:measure_condition_component, :ad_valorem) }

      it { is_expected.to be_ad_valorem }
    end

    context 'when the measure condition component is not an ad valorum component' do
      subject(:measure_condition_component) { create(:measure_condition_component) }

      it { is_expected.not_to be_ad_valorem }
    end
  end

  describe '#expresses_unit?' do
    subject(:measure_condition_component) { build(:measure_condition_component, measurement_unit_code: measurement_unit_code) }

    context 'when the measure condition component specifies a measurement unit code' do
      let(:measurement_unit_code) { 'TNE' }

      it { is_expected.to be_expresses_unit }
    end

    context 'when the measure condition component does not specify a measurement unit code' do
      let(:measurement_unit_code) { nil }

      it { is_expected.not_to be_expresses_unit }
    end
  end
end
