RSpec.describe GoodsNomenclatureReconciliationWorker, type: :worker do
  describe '#perform' do
    let(:embedding_service) { instance_double(EmbeddingService) }

    before do
      allow(GenerateSelfText::MechanicalBuilder).to receive(:call)
      allow(GenerateSelfText::AiBuilder).to receive(:call)
      allow(RelabelGoodsNomenclatureWorker).to receive(:perform_async)
      allow(EmbeddingService).to receive(:new).and_return(embedding_service)
      allow(embedding_service).to receive(:embed_batch) { |texts| texts.map { Array.new(1536, 0.0) } }
    end

    context 'when there are no changes' do
      it 'does nothing' do
        described_class.new.perform

        expect(GenerateSelfText::MechanicalBuilder).not_to have_received(:call)
      end
    end

    describe 'going live today' do
      it 'processes GNs with validity_start_date of today' do
        gn = create(:goods_nomenclature,
                    goods_nomenclature_item_id: '0100000000',
                    validity_start_date: Date.current)

        create(:goods_nomenclature_self_text,
               goods_nomenclature_sid: gn.goods_nomenclature_sid,
               stale: false)

        described_class.new.perform

        expect(
          GoodsNomenclatureSelfText
            .where(goods_nomenclature_sid: gn.goods_nomenclature_sid)
            .first
            .stale,
        ).to be true
      end

      it 'processes indents with validity_start_date of today' do
        gn = create(:goods_nomenclature,
                    goods_nomenclature_item_id: '0200000000',
                    validity_start_date: 1.year.ago)

        create(:goods_nomenclature_indent,
               goods_nomenclature: gn,
               validity_start_date: Date.current)

        create(:goods_nomenclature_self_text,
               goods_nomenclature_sid: gn.goods_nomenclature_sid,
               stale: false)

        described_class.new.perform

        expect(
          GoodsNomenclatureSelfText
            .where(goods_nomenclature_sid: gn.goods_nomenclature_sid)
            .first
            .stale,
        ).to be true
      end

      it 'processes description periods with validity_start_date of today' do
        gn = create(:goods_nomenclature,
                    goods_nomenclature_item_id: '0300000000',
                    validity_start_date: 1.year.ago)

        create(:goods_nomenclature_description_period,
               goods_nomenclature_sid: gn.goods_nomenclature_sid,
               goods_nomenclature_item_id: gn.goods_nomenclature_item_id,
               validity_start_date: Date.current)

        create(:goods_nomenclature_self_text,
               goods_nomenclature_sid: gn.goods_nomenclature_sid,
               stale: false)

        described_class.new.perform

        expect(
          GoodsNomenclatureSelfText
            .where(goods_nomenclature_sid: gn.goods_nomenclature_sid)
            .first
            .stale,
        ).to be true
      end

      it 'does not process future-dated GNs' do
        gn = create(:goods_nomenclature,
                    goods_nomenclature_item_id: '0400000000',
                    validity_start_date: 1.month.from_now)

        create(:goods_nomenclature_self_text,
               goods_nomenclature_sid: gn.goods_nomenclature_sid,
               stale: false)

        described_class.new.perform

        expect(
          GoodsNomenclatureSelfText
            .where(goods_nomenclature_sid: gn.goods_nomenclature_sid)
            .first
            .stale,
        ).to be false
      end
    end

    describe 'inserted today (UK - filename matching)' do
      before do
        allow(TradeTariffBackend).to receive(:uk?).and_return(true)
      end

      it 'processes GNs from files applied today' do
        cds_update = create(:cds_update, :applied_today)

        gn = create(:goods_nomenclature,
                    goods_nomenclature_item_id: '0500000000',
                    validity_start_date: 1.year.ago)

        Sequel::Model.db.run(
          "UPDATE goods_nomenclatures_oplog SET filename = '#{cds_update.filename}' " \
          "WHERE goods_nomenclature_sid = #{gn.goods_nomenclature_sid}",
        )
        GoodsNomenclature.refresh!(concurrently: false)

        create(:goods_nomenclature_self_text,
               goods_nomenclature_sid: gn.goods_nomenclature_sid,
               stale: false)

        described_class.new.perform

        expect(
          GoodsNomenclatureSelfText
            .where(goods_nomenclature_sid: gn.goods_nomenclature_sid)
            .first
            .stale,
        ).to be true
      end

      it 'does not process GNs from files applied yesterday' do
        cds_update = create(:cds_update, :applied_yesterday)

        gn = create(:goods_nomenclature,
                    goods_nomenclature_item_id: '0600000000',
                    validity_start_date: 1.year.ago)

        Sequel::Model.db.run(
          "UPDATE goods_nomenclatures_oplog SET filename = '#{cds_update.filename}' " \
          "WHERE goods_nomenclature_sid = #{gn.goods_nomenclature_sid}",
        )
        GoodsNomenclature.refresh!(concurrently: false)

        create(:goods_nomenclature_self_text,
               goods_nomenclature_sid: gn.goods_nomenclature_sid,
               stale: false)

        described_class.new.perform

        expect(
          GoodsNomenclatureSelfText
            .where(goods_nomenclature_sid: gn.goods_nomenclature_sid)
            .first
            .stale,
        ).to be false
      end
    end

    describe 'inserted today (XI - operation_date matching)' do
      before do
        allow(TradeTariffBackend).to receive(:uk?).and_return(false)
      end

      it 'processes GNs from files applied today' do
        taric_update = create(:taric_update, :applied_today)

        gn = create(:goods_nomenclature,
                    goods_nomenclature_item_id: '0500000000',
                    validity_start_date: 1.year.ago)

        Sequel::Model.db.run(
          "UPDATE goods_nomenclatures_oplog SET operation_date = '#{taric_update.issue_date}' " \
          "WHERE goods_nomenclature_sid = #{gn.goods_nomenclature_sid}",
        )
        GoodsNomenclature.refresh!(concurrently: false)

        create(:goods_nomenclature_self_text,
               goods_nomenclature_sid: gn.goods_nomenclature_sid,
               stale: false)

        described_class.new.perform

        expect(
          GoodsNomenclatureSelfText
            .where(goods_nomenclature_sid: gn.goods_nomenclature_sid)
            .first
            .stale,
        ).to be true
      end

      it 'does not process GNs from files applied yesterday' do
        taric_update = create(:taric_update, :applied_yesterday)

        gn = create(:goods_nomenclature,
                    goods_nomenclature_item_id: '0600000000',
                    validity_start_date: 1.year.ago)

        Sequel::Model.db.run(
          "UPDATE goods_nomenclatures_oplog SET operation_date = '#{taric_update.issue_date}' " \
          "WHERE goods_nomenclature_sid = #{gn.goods_nomenclature_sid}",
        )
        GoodsNomenclature.refresh!(concurrently: false)

        create(:goods_nomenclature_self_text,
               goods_nomenclature_sid: gn.goods_nomenclature_sid,
               stale: false)

        described_class.new.perform

        expect(
          GoodsNomenclatureSelfText
            .where(goods_nomenclature_sid: gn.goods_nomenclature_sid)
            .first
            .stale,
        ).to be false
      end
    end

    describe 'self-text regeneration' do
      it 'marks self-texts stale and regenerates for the chapter' do
        create(:goods_nomenclature, :chapter,
               goods_nomenclature_item_id: '0700000000')

        gn = create(:goods_nomenclature,
                    goods_nomenclature_item_id: '0701000000',
                    validity_start_date: Date.current)

        create(:goods_nomenclature_self_text,
               goods_nomenclature_sid: gn.goods_nomenclature_sid,
               stale: false)

        described_class.new.perform

        self_text = GoodsNomenclatureSelfText
          .where(goods_nomenclature_sid: gn.goods_nomenclature_sid)
          .first

        expect(self_text.stale).to be true
        expect(self_text.search_embedding).to be_present
        expect(GenerateSelfText::AiBuilder).to have_received(:call).with(
          an_instance_of(Chapter),
        ).ordered
        expect(GenerateSelfText::MechanicalBuilder).to have_received(:call).with(
          an_instance_of(Chapter),
        ).ordered
      end

      it 'does not call builders when chapter does not exist' do
        create(:goods_nomenclature,
               goods_nomenclature_item_id: '9901000000',
               validity_start_date: Date.current)

        described_class.new.perform

        expect(GenerateSelfText::MechanicalBuilder).not_to have_received(:call)
        expect(GenerateSelfText::AiBuilder).not_to have_received(:call)
      end
    end

    describe 'search embedding regeneration' do
      it 'defers search embedding regeneration to the relabel page worker' do
        gn = create(:goods_nomenclature,
                    goods_nomenclature_item_id: '1200000000',
                    validity_start_date: Date.current)

        create(:goods_nomenclature_self_text,
               goods_nomenclature_sid: gn.goods_nomenclature_sid,
               self_text: 'Widgets for manufacturing',
               stale: false)

        described_class.new.perform

        self_text = GoodsNomenclatureSelfText
          .where(goods_nomenclature_sid: gn.goods_nomenclature_sid)
          .first

        expect(self_text.search_embedding_stale).to be true
        expect(embedding_service).not_to have_received(:embed_batch)
      end

      it 'marks search embeddings stale for description changes' do
        gn = create(:goods_nomenclature,
                    goods_nomenclature_item_id: '1400000000',
                    validity_start_date: 1.year.ago)

        create(:goods_nomenclature_description_period,
               goods_nomenclature_sid: gn.goods_nomenclature_sid,
               goods_nomenclature_item_id: gn.goods_nomenclature_item_id,
               validity_start_date: Date.current)

        create(:goods_nomenclature_self_text,
               goods_nomenclature_sid: gn.goods_nomenclature_sid,
               self_text: 'Widgets for manufacturing',
               stale: false)

        described_class.new.perform

        self_text = GoodsNomenclatureSelfText
          .where(goods_nomenclature_sid: gn.goods_nomenclature_sid)
          .first

        expect(self_text.search_embedding_stale).to be true
      end

      it 'does not call embedding service when no self-texts exist' do
        create(:goods_nomenclature,
               goods_nomenclature_item_id: '1300000000',
               validity_start_date: Date.current)

        described_class.new.perform

        expect(embedding_service).not_to have_received(:embed_batch)
      end
    end

    describe 'label staleness' do
      it 'marks labels stale for description changes' do
        gn = create(:goods_nomenclature,
                    goods_nomenclature_item_id: '0800000000',
                    validity_start_date: 1.year.ago)

        create(:goods_nomenclature_description_period,
               goods_nomenclature_sid: gn.goods_nomenclature_sid,
               goods_nomenclature_item_id: gn.goods_nomenclature_item_id,
               validity_start_date: Date.current)

        create(:goods_nomenclature_label, goods_nomenclature_sid: gn.goods_nomenclature_sid)

        described_class.new.perform

        label = GoodsNomenclatureLabel
          .where(goods_nomenclature_sid: gn.goods_nomenclature_sid)
          .first

        expect(label.stale).to be true
        expect(RelabelGoodsNomenclatureWorker).to have_received(:perform_async)
      end

      it 'marks labels stale for structure-only changes' do
        gn = create(:goods_nomenclature,
                    goods_nomenclature_item_id: '1000000000',
                    validity_start_date: Date.current)

        create(:goods_nomenclature_label, goods_nomenclature_sid: gn.goods_nomenclature_sid)

        described_class.new.perform

        label = GoodsNomenclatureLabel
          .where(goods_nomenclature_sid: gn.goods_nomenclature_sid)
          .first

        expect(label.stale).to be true
        expect(RelabelGoodsNomenclatureWorker).to have_received(:perform_async)
      end
    end

    describe 'idempotency' do
      it 'produces the same result when run twice' do
        gn = create(:goods_nomenclature,
                    goods_nomenclature_item_id: '1100000000',
                    validity_start_date: Date.current)

        create(:goods_nomenclature_self_text,
               goods_nomenclature_sid: gn.goods_nomenclature_sid,
               stale: false)

        described_class.new.perform
        described_class.new.perform

        self_text = GoodsNomenclatureSelfText
          .where(goods_nomenclature_sid: gn.goods_nomenclature_sid)
          .first

        expect(self_text.stale).to be true
      end
    end
  end

  describe 'sidekiq options' do
    it 'uses the default queue' do
      expect(described_class.sidekiq_options['queue']).to eq(:default)
    end

    it 'retries twice' do
      expect(described_class.sidekiq_options['retry']).to eq(2)
    end
  end
end
