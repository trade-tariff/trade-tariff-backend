RSpec.describe Reporting::Differences::Loaders::OmittedDutyMeasures do
  describe '#data' do
    it 'reports measures that applied a year ago but no longer apply' do
      past_measure = double(
        goods_nomenclature_item_id: '0101000000',
        geographical_area_id: '1011',
        measure_type_id: '112',
        effective_start_date: Date.new(2025, 1, 2),
        ordernumber: 'PAST',
        additional_code_type_id: 'A',
        additional_code_id: '123',
      )
      current_measure = double(
        goods_nomenclature_item_id: '0101000000',
        geographical_area_id: '1011',
        measure_type_id: '112',
        effective_start_date: Date.new(2026, 1, 2),
        ordernumber: 'CURRENT',
        additional_code_type_id: nil,
        additional_code_id: nil,
      )
      past_declarable = double(
        declarable?: true,
        goods_nomenclature_item_id: '0101000000',
        producline_suffix: '80',
        applicable_measures: [past_measure],
      )
      current_declarable = double(
        declarable?: true,
        goods_nomenclature_item_id: '0101000000',
        producline_suffix: '80',
        applicable_measures: [current_measure],
      )
      chapters = {
        (Time.zone.today - 1.year).iso8601 => double(descendants: [past_declarable]),
        Time.zone.today.iso8601 => double(descendants: [current_declarable]),
      }
      report = double

      allow(report).to receive(:each_chapter) do |eager:, as_of:, &block|
        expect(eager).to eq(Reporting::Differences::GOODS_NOMENCLATURE_MEASURE_EAGER)
        block.call(chapters.fetch(as_of))
      end

      expect(described_class.new(report).data).to eq([
        ['0101000000', '1011', '112', '02/01', 'PAST', 'A123'],
      ])
    end
  end
end
