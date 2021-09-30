RSpec.describe MeursingMeasure do
  it { expect(described_class.primary_key).to eq(:measure_sid) }

  describe '#all' do
    before { measures }

    let(:meursing_measure) do
      create(
        :measure,
        additional_code_id: '000', # Meursing measures have an additional code
        additional_code_type_id: '7', # Meursing additional code type
        goods_nomenclature: nil, # Meursing measures have no goods nomenclature
        goods_nomenclature_item_id: nil, # Meursing measures have no goods nomenclature
        goods_nomenclature_sid: nil, # Meursing measures have no goods nomenclature
        measure_type_id: '672', # Meursing measures have there own measure types
        reduction_indicator: '1', # Meursing measures match the reduction indicator of the root measures
      )
    end

    let(:regular_measure) { create(:measure) }

    context 'when there are meursing measures' do
      let(:measures) { [regular_measure, meursing_measure] }

      it 'returns only meursing measures' do
        expect(described_class.all.map(&:measure_sid)).to eq([meursing_measure.measure_sid])
      end
    end

    context 'when there no meursing measures' do
      let(:measures) { [regular_measure] }

      it 'returns only meursing measures' do
        expect(described_class.all).to eq([])
      end
    end
  end

  describe '#current?' do
    subject(:meursing_measure) { build(:meursing_measure, validity_end_date: validity_end_date, base_regulation_effective_end_date: validity_end_date) }

    around { |example| TimeMachine.now { example.run } }

    context 'when the validity end date is null' do
      let(:validity_end_date) { nil }

      it { is_expected.to be_current }
    end

    context 'when the validity end date is equal to or after the current point in time' do
      let(:validity_end_date) { Time.zone.tomorrow }

      it { is_expected.to be_current }
    end

    context 'when the validity end date is before the current point in time' do
      let(:validity_end_date) { Time.zone.yesterday }

      it { is_expected.not_to be_current }
    end
  end
end
