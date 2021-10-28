RSpec.describe MeasureComponent do
  it_behaves_like 'a component', :measure_component

  describe '#id' do
    subject(:component) { build(:measure_component, measure_sid: 'foo', duty_expression_id: 'bar') }

    it { expect(component.id).to eq('foo-bar') }
  end
end
