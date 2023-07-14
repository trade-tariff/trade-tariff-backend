RSpec.shared_examples_for 'a component' do |type|
  it_is_associated 'one to one to', :duty_expression do
    let(:duty_expression_id) { Forgery(:basic).text(exactly: 3) }
  end

  it_is_associated 'one to one to', :measurement_unit do
    let(:measurement_unit_code) { Forgery(:basic).text(exactly: 3) }
  end

  it_is_associated 'one to one to', :monetary_unit do
    let(:monetary_unit_code) { Forgery(:basic).text(exactly: 3) }
  end

  it_is_associated 'one to one to', :measurement_unit_qualifier do
    let(:measurement_unit_qualifier_code) { Forgery(:basic).text(exactly: 1) }
  end

  describe '#expresses_unit?' do
    subject(:component) { build(type, measurement_unit_code:) }

    context 'when the component specifies a measurement unit code' do
      let(:measurement_unit_code) { 'TNE' }

      it { is_expected.to be_expresses_unit }
    end

    context 'when the component does not specify a measurement unit code' do
      let(:measurement_unit_code) { nil }

      it { is_expected.not_to be_expresses_unit }
    end
  end

  describe '#unit_for' do
    subject(:unit_for) { component.unit_for(measure) }

    shared_examples_for 'a component with a measurement unit' do |measurement_unit_code, measurement_unit_qualifier_code|
      it { is_expected.to include(measurement_unit_code:, measurement_unit_qualifier_code:) }
    end

    it_behaves_like 'a component with a measurement unit', 'TNE', 'I' do
      let(:component) { build(type, measurement_unit_code: 'TNE', measurement_unit_qualifier_code: 'I') }
      let(:measure) { build(:measure) }
    end

    it_behaves_like 'a component with a measurement unit', 'SPQ', 'LTR' do
      let(:component) { create(type, :small_producers_quotient) }
      let(:measure) { build(:measure, :excise, :with_percentage_alcohol_and_volume_per_hl_component) }
    end

    it_behaves_like 'a component with a measurement unit', 'SPQ', 'LPA' do
      let(:component) { create(type, :small_producers_quotient) }
      let(:measure) { build(:measure, :excise, :with_liters_of_pure_alcohol_measure_component) }
    end

    it_behaves_like 'a component with a measurement unit', 'SPQ', nil do
      let(:component) { create(type, :small_producers_quotient) }
      let(:measure) { build(:measure) } # not an excise measure
    end
  end

  describe '#zero_duty?' do
    context 'when the component has a zero duty amount' do
      subject(:component) { create(type, duty_amount: 0) }

      it { is_expected.to be_zero_duty }
    end

    context 'when the component has a non-zero duty amount' do
      subject(:component) { create(type, duty_amount: 15) }

      it { is_expected.not_to be_zero_duty }
    end
  end

  describe '#ad_valorem?' do
    context 'when the component is an ad valorum component' do
      subject(:component) { create(type, :ad_valorem) }

      it { is_expected.to be_ad_valorem }
    end

    context 'when the component is not an ad valorum component' do
      subject(:component) { build(type) }

      it { is_expected.not_to be_ad_valorem }
    end
  end
end
