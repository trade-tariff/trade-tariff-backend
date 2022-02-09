RSpec.describe Api::V2::ValidityPeriodPresenter do
  subject(:presenter) { described_class.new(item) }

  describe '#validity_period_id' do
    let(:subject) { presenter.validity_period_id }

    let(:expected_id) do
      "#{item.goods_nomenclature_item_id}-#{item.validity_start_date.to_i}-"
    end

    context 'with commodity' do
      let(:item) { create :commodity, validity_end_date: nil }

      it { is_expected.to eql expected_id }
    end

    context 'with heading' do
      let(:item) { create :heading, validity_end_date: nil }

      it { is_expected.to eql expected_id }
    end

    context 'with start and end dates' do
      let(:item) { create :commodity, validity_end_date: Date.tomorrow }

      let(:expected_id) do
        "#{item.goods_nomenclature_item_id}-#{item.validity_start_date.to_i}-" \
          "#{item.validity_end_date.to_i}"
      end

      it { is_expected.to eql expected_id }
    end
  end
end
