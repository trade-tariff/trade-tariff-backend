# rubocop:disable RSpec/DescribeClass
RSpec.describe 'labels:relabel' do
  subject(:relabel) { suppress_output { Rake::Task['labels:relabel'].invoke } }

  after do
    Rake::Task['labels:relabel'].reenable
    ENV.delete('CHAPTER')
  end

  it 'marks labels stale and records an update version' do
    label = create(:goods_nomenclature_label, stale: false)
    allow(RelabelGoodsNomenclatureWorker).to receive(:perform_async)

    expect { relabel }.to change(Version, :count).by(1)

    expect(label.reload.stale).to be true
    expect(label.versions.order(:id).last.event).to eq('update')
  end
end
# rubocop:enable RSpec/DescribeClass
