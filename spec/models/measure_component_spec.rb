require 'rails_helper'

describe MeasureComponent do
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

  describe '#zero_duty?' do
    context 'when the measure component has a zero duty amount' do
      subject(:measure_component) { create(:measure_component, duty_amount: 0) }

      it { is_expected.to be_zero_duty }
    end

    context 'when the measure component has a non-zero duty amount' do
      subject(:measure_component) { create(:measure_component, duty_amount: 15) }

      it { is_expected.not_to be_zero_duty }
    end
  end

  describe '#ad_valorem?' do
    context 'when the measure component is an ad valorum component' do
      subject(:measure_component) { create(:measure_component, :ad_valorem) }

      it { is_expected.to be_ad_valorem }
    end

    context 'when the measure component is not an ad valorum component' do
      subject(:measure_component) { build(:measure_component) }

      it { is_expected.not_to be_ad_valorem }
    end
  end
end
