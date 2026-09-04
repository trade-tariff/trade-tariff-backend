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

    it 'returns superseded with the successor id, marked for auto-deletion' do
      expect(result[:reason]).to eq(:superseded)
      expect(result[:reason_label]).to eq('Superseded')
      expect(result[:auto_deletion]).to be(true)
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

  context 'when multiple successor rows resolve to the same item id' do
    let(:commodity) { create(:commodity, validity_end_date: Time.zone.yesterday) }
    let(:search_reference) { create(:search_reference, referenced: commodity, title: 'superseded item') }

    before do
      # Two successor rows for the same absorbed commodity, landing on the same
      # target item id under different productline suffixes (e.g. grouping vs.
      # non-grouping variants of the successor) — a legitimate duplicate at the
      # item id level.
      create(
        :goods_nomenclature_successor,
        absorbed_goods_nomenclature_item_id: commodity.goods_nomenclature_item_id,
        absorbed_productline_suffix: commodity.producline_suffix,
        goods_nomenclature_item_id: '0101999000',
        productline_suffix: '10',
      )
      create(
        :goods_nomenclature_successor,
        absorbed_goods_nomenclature_item_id: commodity.goods_nomenclature_item_id,
        absorbed_productline_suffix: commodity.producline_suffix,
        goods_nomenclature_item_id: '0101999000',
        productline_suffix: '20',
      )
    end

    it 'returns each successor item id only once' do
      expect(result[:successor_ids]).to eq(%w[0101999000])
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

    it 'returns unknown, marked for auto-deletion' do
      expect(result[:reason]).to eq(:unknown)
      expect(result[:reason_label]).to eq('Unknown')
      expect(result[:auto_deletion]).to be(true)
      expect(result[:removal_alert_required]).to be(true)
      expect(result[:successor_ids]).to eq([])
    end
  end

  describe 'goods_nomenclature_url' do
    context 'when the search reference points at a chapter' do
      let(:search_reference) { create(:search_reference, :with_chapter, title: 'chapter item') }

      it 'builds the chapter page URL under the configured frontend host' do
        expect(result[:goods_nomenclature_url]).to eq("#{TradeTariffBackend.frontend_host}/chapters/01")
      end
    end

    context 'when the search reference points at a heading' do
      let(:search_reference) { create(:search_reference, :with_heading, title: 'heading item') }

      it 'builds the heading page URL under the configured frontend host' do
        expect(result[:goods_nomenclature_url]).to eq("#{TradeTariffBackend.frontend_host}/headings/0101")
      end
    end

    context 'when the search reference points at a subheading' do
      let(:search_reference) { create(:search_reference, :with_subheading, title: 'subheading item') }

      it 'builds the subheading page URL from the item id and productline suffix' do
        expect(result[:goods_nomenclature_url]).to eq("#{TradeTariffBackend.frontend_host}/subheadings/0101210000-10")
      end
    end

    context 'when the search reference points at a commodity' do
      let(:search_reference) { create(:search_reference, :with_commodity, title: 'commodity item') }

      it 'builds the commodity page URL under the configured frontend host' do
        expect(result[:goods_nomenclature_url]).to eq("#{TradeTariffBackend.frontend_host}/commodities/0101291000")
      end
    end

    context 'when FRONTEND_HOST is not configured' do
      let(:search_reference) { create(:search_reference, :with_commodity, title: 'commodity item') }

      before { allow(TradeTariffBackend).to receive(:frontend_host).and_return(nil) }

      it 'omits the url rather than building a broken one' do
        expect(result[:goods_nomenclature_url]).to be_nil
      end
    end

    context 'when the referenced class has no known frontend path' do
      let(:search_reference) do
        search_reference = create(:search_reference, :with_commodity, title: 'unmapped class')
        # referenced_class is derived from the live referenced association (see
        # SearchReference#referenced_class), so it has to be stubbed rather than
        # set directly to simulate an unmapped class.
        allow(search_reference).to receive(:referenced_class).and_return('GoodsNomenclature')
        search_reference
      end

      it 'omits the url rather than building an incomplete one' do
        expect(result[:goods_nomenclature_url]).to be_nil
      end
    end
  end
end
