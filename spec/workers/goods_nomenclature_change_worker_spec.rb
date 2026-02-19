RSpec.describe GoodsNomenclatureChangeWorker, type: :worker do
  describe '#perform' do
    let(:chapter_code) { '01' }

    before do
      allow(GenerateSelfText::MechanicalBuilder).to receive(:call)
    end

    describe 'marking self-texts stale' do
      let!(:self_text) do
        create(:goods_nomenclature_self_text,
               goods_nomenclature_sid: 100,
               stale: false)
      end

      let(:sid_change_map) { { '100' => %w[structure_changed] } }

      it 'marks affected self-texts as stale and clears embedding' do
        described_class.new.perform(chapter_code, sid_change_map)
        self_text.reload
        expect(self_text.stale).to be true
        expect(self_text.search_embedding).to be_nil
      end

      it 'does not mark unaffected self-texts' do
        other = create(:goods_nomenclature_self_text,
                       goods_nomenclature_sid: 999,
                       stale: false)

        described_class.new.perform(chapter_code, sid_change_map)
        expect(other.reload.stale).to be false
      end
    end

    describe 'mechanical self-text regeneration' do
      let(:sid_change_map) { { '100' => %w[structure_changed] } }

      it 'calls MechanicalBuilder for the chapter' do
        create(:goods_nomenclature, :chapter,
               goods_nomenclature_item_id: '0100000000')

        described_class.new.perform(chapter_code, sid_change_map)

        expect(GenerateSelfText::MechanicalBuilder).to have_received(:call).with(
          an_instance_of(Chapter),
        )
      end

      it 'does nothing when chapter does not exist' do
        described_class.new.perform('99', sid_change_map)
        expect(GenerateSelfText::MechanicalBuilder).not_to have_received(:call)
      end
    end

    describe 'label invalidation on description change' do
      let(:sid_change_map) { { '100' => %w[description_changed] } }

      it 'destroys labels for SIDs with description changes' do
        create(:goods_nomenclature_label, goods_nomenclature_sid: 100)

        described_class.new.perform(chapter_code, sid_change_map)

        # Oplog destroy writes a D record; check the last operation
        last_op = GoodsNomenclatureLabel::Operation
          .where(goods_nomenclature_sid: 100)
          .order(Sequel.desc(:oid))
          .first
        expect(last_op[:operation]).to eq('D')
      end

      it 'does not destroy labels for SIDs without description changes' do
        create(:goods_nomenclature_label, goods_nomenclature_sid: 200)
        sid_change_map_no_desc = { '200' => %w[structure_changed] }

        described_class.new.perform(chapter_code, sid_change_map_no_desc)

        last_op = GoodsNomenclatureLabel::Operation
          .where(goods_nomenclature_sid: 200)
          .order(Sequel.desc(:oid))
          .first
        expect(last_op[:operation]).not_to eq('D')
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
