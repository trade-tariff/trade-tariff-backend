RSpec.describe SearchReferences::InvalidationReasonService do
  subject(:result) { described_class.call(search_reference) }

  before do
    TradeTariffRequest.time_machine_now = Time.current
  end

  context 'when the goods nomenclature is expired without a successor' do
    let(:search_reference) do
      create(:search_reference, :with_non_current_commodity, title: 'expired item')
    end

    it 'returns expired and marks it for auto-deletion' do
      expect(result[:reason]).to eq(:expired)
      expect(result[:reason_label]).to eq('Expired')
      expect(result[:auto_deletion]).to be(true)
      expect(result[:removal_alert_required]).to be(true)
      expect(result[:successor_ids]).to eq([])
    end
  end

  context 'when the goods nomenclature is superseded by one successor' do
    let(:commodity) { create(:commodity, validity_end_date: Time.zone.yesterday) }
    let(:search_reference) { create(:search_reference, referenced: commodity, title: 'superseded item') }

    before do
      create(
        :goods_nomenclature_successor,
        absorbed_goods_nomenclature_item_id: commodity.goods_nomenclature_item_id,
        absorbed_productline_suffix: commodity.producline_suffix,
        goods_nomenclature_item_id: '0101999000',
      )
    end

    it 'returns superseded with the successor id, flagged for review rather than deleted' do
      expect(result[:reason]).to eq(:superseded)
      expect(result[:reason_label]).to eq('Superseded')
      expect(result[:auto_deletion]).to be(false)
      expect(result[:removal_alert_required]).to be(true)
      expect(result[:successor_ids]).to eq(%w[0101999000])
    end
  end

  context 'when the goods nomenclature is superseded by multiple successors' do
    let(:commodity) { create(:commodity, validity_end_date: Time.zone.yesterday) }
    let(:search_reference) { create(:search_reference, referenced: commodity, title: 'superseded item') }

    before do
      create(
        :goods_nomenclature_successor,
        absorbed_goods_nomenclature_item_id: commodity.goods_nomenclature_item_id,
        absorbed_productline_suffix: commodity.producline_suffix,
        goods_nomenclature_item_id: '0101999000',
      )
      create(
        :goods_nomenclature_successor,
        absorbed_goods_nomenclature_item_id: commodity.goods_nomenclature_item_id,
        absorbed_productline_suffix: commodity.producline_suffix,
        goods_nomenclature_item_id: '0101998000',
      )
    end

    it 'returns superseded with every successor id' do
      expect(result[:reason]).to eq(:superseded)
      expect(result[:successor_ids]).to match_array(%w[0101999000 0101998000])
    end
  end

  context 'when the associated goods nomenclature is missing' do
    let(:search_reference) do
      search_reference = create(:search_reference, :with_commodity, title: 'missing item')
      # Simulate a stored SID that no longer resolves to any goods nomenclature,
      # without touching the persisted row (avoids cascading into its indents/descriptions).
      search_reference.goods_nomenclature_sid += 1_000_000
      search_reference
    end

    it 'returns missing and marks it for auto-deletion' do
      expect(result[:reason]).to eq(:missing)
      expect(result[:reason_label]).to eq('Missing')
      expect(result[:auto_deletion]).to be(true)
      expect(result[:removal_alert_required]).to be(true)
      expect(result[:successor_ids]).to eq([])
      expect(result[:validity_start_date]).to be_nil
      expect(result[:validity_end_date]).to be_nil
      expect(result[:title]).to eq('missing item')
    end
  end

  context 'when the goods nomenclature is not current but the data does not prove why' do
    let(:commodity) { create(:commodity) }
    let(:search_reference) do
      search_reference = create(:search_reference, referenced: commodity, title: 'unknown item')
      allow(search_reference).to receive(:referenced).and_return(commodity)
      search_reference
    end

    before { allow(commodity).to receive(:current?).and_return(false) }

    it 'returns unknown, flagged for review rather than deleted' do
      expect(result[:reason]).to eq(:unknown)
      expect(result[:reason_label]).to eq('Unknown')
      expect(result[:auto_deletion]).to be(false)
      expect(result[:removal_alert_required]).to be(true)
      expect(result[:successor_ids]).to eq([])
    end
  end
end
