RSpec.describe GenerateGoodsNomenclaturesCsvReportWorker, type: :worker do
  subject(:do_perform) { silence { described_class.new.perform } }

  before do
    create(
      :chapter,
      :with_indent,
      goods_nomenclature_sid: 0,
      producline_suffix: '80',
      goods_nomenclature_item_id: '0100000000',
    )
    create(
      :heading,
      :with_indent,
      goods_nomenclature_sid: 1,
      producline_suffix: '80',
      goods_nomenclature_item_id: '0101000000',
    )
    create(
      :heading,
      :with_indent,
      :non_current,
      goods_nomenclature_sid: 2,
      producline_suffix: '80',
      goods_nomenclature_item_id: '0102000000',
    )
  end

  it 'generates a report for current goods nomenclatures' do
    allow(TariffSynchronizer::FileService).to receive(:write_file)

    do_perform

    expect(TariffSynchronizer::FileService).to have_received(:write_file).with(
      "uk/goods_nomenclatures/#{Time.zone.today.iso8601}.csv",
      include('0101000000'),
    )
  end

  it 'excludes non-current goods nomenclatures' do
    allow(TariffSynchronizer::FileService).to receive(:write_file)

    do_perform

    expect(TariffSynchronizer::FileService).not_to have_received(:write_file).with(
      "uk/goods_nomenclatures/#{Time.zone.today.iso8601}.csv",
      include('0201000000'),
    )
  end
end
