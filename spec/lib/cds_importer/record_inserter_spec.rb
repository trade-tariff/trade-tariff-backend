RSpec.describe CdsImporter::RecordInserter do
  subject(:inserter) { described_class.new('tariff_dailyExtract_v1_20231101T000000.gzip') }

  let(:operation_klass) do
    class_double(GoodsNomenclature::Operation, columns: %i[goods_nomenclature_item_id filename], multi_insert: nil)
  end

  let(:cds_entity) do
    instance = double(
      skip_import?: false,
      class: double(operation_klass:),
      operation: :create,
      values: { goods_nomenclature_item_id: '0101210000' },
    )

    CdsImporter::CdsEntity.new('1', 'GoodsNomenclature', instance, instance_double(CdsImporter::EntityMapper::GoodsNomenclatureMapper))
  end

  describe '#after_parse' do
    context 'when a batch insert fails' do
      before do
        allow(ActiveSupport::Notifications).to receive(:instrument) { |_event, **_opts, &block| block&.call }
        allow(operation_klass).to receive(:multi_insert).and_raise(StandardError, 'constraint violation')
      end

      it 'raises rather than swallowing the error' do
        inserter.process_record(cds_entity)

        expect { inserter.after_parse }.to raise_error(StandardError, 'constraint violation')
      end
    end
  end
end
