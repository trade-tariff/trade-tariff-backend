require 'cds_importer/entity_mapper'

RSpec.describe TariffSynchronizer::CdsUpdate do
  describe '#import' do
    around do |example|
      original_path = TariffSynchronizer.root_path
      TariffSynchronizer.root_path = 'spec/fixtures'
      example.run
      TariffSynchronizer.root_path = original_path
    end

    context 'when the current file has missing insertable content' do
      subject(:do_import) { missing_measure_condition_update.import! }

      let(:extra_measure_condition_update) { create(:cds_update, :pending, filename: 'extra_measure_condition.gzip') }
      let(:missing_measure_condition_update) { create(:cds_update, :pending, filename: 'missing_measure_condition.gzip') }

      let(:expected_inserts) do
        {
          'operations' => {
            'create' => {
              'count' => 1,
              'duration' => be_a(Float),
              'MeasureComponent' => { 'count' => 1, 'duration' => be_a(Float), 'mapping_path' => 'measureComponent' },
            },
            'update' => {
              'count' => 1,
              'duration' => be_a(Float),
              'Measure' => { 'count' => 1, 'duration' => be_a(Float), 'mapping_path' => nil },
            },
            'destroy' => { 'count' => 0, 'duration' => 0 },
            'destroy_missing' => {
              'count' => 1,
              'duration' => be_a(Float),
              'MeasureCondition' => {
                'count' => 1,
                'duration' => be_a(Float),
                'mapping_path' => 'measureCondition',
                'records' => [{ 'oid' => Integer, 'measure_condition_sid' => 20_115_851 }],
              },
            },
            'skipped' => { 'count' => 0, 'duration' => 0 },
          },
          'total_count' => 3,
          'total_duration' => be_a(Float),
        }
      end

      it 'removes the missing content' do
        extra_measure_condition_update.import!

        expect { do_import }.to change(MeasureCondition, :count).by(-1)
      end

      it 'appends the correct insert information to the update' do
        extra_measure_condition_update.import!

        do_import

        expect(missing_measure_condition_update.inserts).to match_json_expression(expected_inserts)
      end
    end
  end
end
