shared_examples_for 'a component' do |type|
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
    subject(:component) { build(type, measurement_unit_code: measurement_unit_code) }

    context 'when the component specifies a measurement unit code' do
      let(:measurement_unit_code) { 'TNE' }

      it { is_expected.to be_expresses_unit }
    end

    context 'when the component does not specify a measurement unit code' do
      let(:measurement_unit_code) { nil }

      it { is_expected.not_to be_expresses_unit }
    end
  end

  describe '#unit' do
    subject(:component) do
      build(
        type,
        measurement_unit_code: 'TNE',
        measurement_unit_qualifier_code: 'I',
      )
    end

    it 'returns the properly formatted unit' do
      identifier_key = type == :measure_condition_component ? :condition_component_id : :component_id

      expect(component.unit).to eq(
        identifier_key => component.pk.join('-'),
        measurement_unit_code: 'TNE',
        measurement_unit_qualifier_code: 'I',
      )
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
