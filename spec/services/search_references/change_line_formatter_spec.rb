RSpec.describe SearchReferences::ChangeLineFormatter do
  describe '.format_line' do
    subject(:line) { described_class.format_line(change) }

    let(:change) do
      {
        goods_nomenclature_item_id: '0101210000',
        title: 'live horses',
        usage: SearchReference::SEARCH_USAGE,
      }
    end

    it { is_expected.to eq('0101210000 — live horses') }

    context 'when the search reference is used only by FPO' do
      before { change[:usage] = SearchReference::FPO_USAGE }

      it { is_expected.to eq('0101210000 — live horses [FPO only]') }
    end

    context 'when there is a goods nomenclature URL and successors' do
      before do
        change[:goods_nomenclature_url] = 'https://example.com/commodities/0101210000'
        change[:successor_ids] = %w[0101999000 0101888000]
      end

      it { is_expected.to eq('0101210000 — live horses (https://example.com/commodities/0101210000) (successors: 0101999000, 0101888000)') }
    end

    context 'when previous values differ' do
      before do
        change[:previous_goods_nomenclature_item_id] = '0101100000'
        change[:previous_title] = 'horses'
        change[:previous_usage] = SearchReference::FPO_USAGE
      end

      it { is_expected.to eq('0101210000 — live horses (previously: commodity 0101100000, title "horses", usage fpo)') }
    end

    context 'when previous values are the same as the current values' do
      before do
        change[:previous_goods_nomenclature_item_id] = '0101210000'
        change[:previous_title] = 'live horses'
        change[:previous_usage] = SearchReference::SEARCH_USAGE
      end

      it { is_expected.to eq('0101210000 — live horses') }
    end
  end

  describe '.format_list' do
    it 'formats each change as a bullet line' do
      changes = [
        { goods_nomenclature_item_id: '01', title: 'a' },
        { goods_nomenclature_item_id: '02', title: 'b' },
      ]

      expect(described_class.format_list(changes)).to eq("* 01 — a\n* 02 — b")
    end
  end
end
