# rubocop:disable RSpec/DescribeClass
RSpec.describe 'labels tasks' do
  around do |example|
    original_chapter = ENV.fetch('CHAPTER', nil)
    ENV.delete('CHAPTER')
    example.run
  ensure
    original_chapter ? ENV['CHAPTER'] = original_chapter : ENV.delete('CHAPTER')
  end

  describe 'labels:relabel' do
    subject(:relabel) { suppress_output { Rake::Task['labels:relabel'].invoke } }

    after { Rake::Task['labels:relabel'].reenable }

    it 'marks labels stale and records an update version' do
      label = create(:goods_nomenclature_label, stale: false)
      allow(RelabelGoodsNomenclatureWorker).to receive(:perform_async)

      expect { relabel }.to change(Version, :count).by(1)

      expect(label.reload.stale).to be true
      expect(label.versions.order(:id).last.event).to eq('update')
    end
  end

  describe 'labels:gaps' do
    subject(:gaps) { Rake::Task['labels:gaps'].invoke }

    let(:task) { Rake::Task['labels:gaps'] }

    after { task.reenable }

    it 'reports zero totals when there are no declarable commodities' do
      expect { gaps }.to output(/TOTAL\s+0\s+0\s+0\s+0\s+0\s+0\.0%.*No gaps found - full coverage, nothing stale or drifted!/m).to_stdout
    end

    it 'reports the total and missing counts for a chapter with an unlabeled commodity' do
      create(:commodity, goods_nomenclature_item_id: '0101210000')

      expect { gaps }.to output(/01\s+\?\s+1\s+1\s+0\s+0\s+1\s+0\.0%/).to_stdout
    end

    it 'reports mixed gap totals and reasons ordered by commodity code' do
      missing = create(:commodity, goods_nomenclature_item_id: '0101299000')
      drifted = create(:commodity, goods_nomenclature_item_id: '0101291000')
      stale = create(:commodity, goods_nomenclature_item_id: '0101210000')
      current = create(:commodity, goods_nomenclature_item_id: '0101300000')

      create(:goods_nomenclature_label, goods_nomenclature: current)
      create(:goods_nomenclature_label, :stale, goods_nomenclature: stale)
      create(:goods_nomenclature_self_text, goods_nomenclature: drifted, self_text: 'Changed context')
      create(:goods_nomenclature_label, goods_nomenclature: drifted, context_hash: Digest::SHA256.hexdigest('Old context'))

      expect { gaps }.to output(
        /01\s+\?\s+4\s+1\s+1\s+1\s+3\s+75\.0%.*
         TOTAL\s+4\s+1\s+1\s+1\s+3\s+75\.0%.*
         #{stale.goods_nomenclature_item_id}\s+80\s+stale.*
         #{drifted.goods_nomenclature_item_id}\s+80\s+drifted.*
         #{missing.goods_nomenclature_item_id}\s+80\s+missing.*
         Total\s+needing\s+work:\s+3/mx,
      ).to_stdout
    end
  end
end
# rubocop:enable RSpec/DescribeClass
