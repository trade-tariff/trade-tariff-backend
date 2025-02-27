RSpec.describe MeursingMeasure do
  before do
    TradeTariffRequest.time_machine_now = Time.current
  end

  it { expect(described_class.primary_key).to eq(:measure_sid) }

  describe '#all' do
    before { measures }

    let(:meursing_measure) do
      create(
        :measure,
        :with_base_regulation,
        additional_code_id: '000',
        additional_code_type_id: '7',
        goods_nomenclature: nil,
        goods_nomenclature_item_id: nil,
        goods_nomenclature_sid: nil,
        measure_type_id: '672',
        reduction_indicator: '1',
      )
    end

    let(:regular_measure) { create(:measure, :with_base_regulation) }

    context 'when there are meursing measures' do
      let(:measures) { [regular_measure, meursing_measure] }

      it 'returns only meursing measures' do
        expect(described_class.all.map(&:measure_sid)).to eq([meursing_measure.measure_sid])
      end
    end

    context 'when there are no meursing measures' do
      let(:measures) { [regular_measure] }

      it 'returns only meursing measures' do
        expect(described_class.all).to eq([])
      end
    end
  end

  describe '#current?' do
    subject(:meursing_measure) do
      create(
        :meursing_measure,
        validity_end_date:,
        generating_regulation: create(:base_regulation, effective_end_date: validity_end_date),
      )
    end

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
