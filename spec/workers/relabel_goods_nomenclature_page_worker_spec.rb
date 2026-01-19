RSpec.describe RelabelGoodsNomenclaturePageWorker, type: :worker do
  describe '#perform' do
    let(:page_number) { 1 }

    let(:labels) { [build(:goods_nomenclature_label)] }

    before do
      create(:commodity)

      allow(LabelService).to receive(:call).with(anything).and_return(labels)
      allow(Rails.logger).to receive(:info).and_call_original
    end

    it 'calls LabelService with the batch' do
      described_class.new.perform(page_number)

      expect(LabelService).to have_received(:call) do |batch|
        expect(batch.size).to eq(1)
      end
    end

    it 'saves each label' do
      expect { described_class.new.perform(page_number) }.to change(GoodsNomenclatureLabel, :count).by(1)
    end

    it 'logs the result' do
      described_class.new.perform(page_number)

      expect(Rails.logger).to have_received(:info).with(/Relabelled page \d+ with \d+ labels/)
    end
  end
end
