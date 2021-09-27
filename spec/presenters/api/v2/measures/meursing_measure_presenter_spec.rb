RSpec.describe Api::V2::Measures::MeursingMeasurePresenter do
  subject(:presenter) { described_class.new(meursing_measure) }

  let(:meursing_measure) { create(:meursing_measure, :with_additional_code) }

  describe '#additional_code_id' do
    it { expect(presenter.additional_code_id).to eq(meursing_measure.additional_code_sid) }
  end

  describe '#measure_component_ids' do
    context 'when there are no measure components' do
      let(:meursing_measure) { create(:meursing_measure) }
      let(:expected_measure_component_ids) { [] }

      it { expect(presenter.measure_component_ids).to eq(expected_measure_component_ids) }
    end

    context 'when there are measure components' do
      let(:meursing_measure) { create(:meursing_measure, :with_measure_components) }

      let(:expected_measure_component_ids) do
        ["#{meursing_measure.measure_sid}-#{meursing_measure.measure_components.first.duty_expression_id}"]
      end

      it { expect(presenter.measure_component_ids).to eq(expected_measure_component_ids) }
    end
  end
end
