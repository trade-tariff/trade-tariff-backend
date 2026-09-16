RSpec.describe CdsImporter::ExcelWriter::QuotaDefinition do
  subject(:mapper) { described_class.new(models) }

  let(:quota_definition) do
    instance_double(
      QuotaDefinition,
      class: instance_double(Class, name: 'QuotaDefinition'),
      quota_order_number_id: '123456',
      quota_definition_sid: 111,
      operation: 'C',
      critical_state: 'Y',
      critical_threshold: 50,
      initial_volume: 1000,
      volume: 500,
      maximum_precision: 2,
      validity_start_date: Time.utc(2025, 1, 1, 0, 0, 0),
      validity_end_date: Time.utc(2025, 12, 31, 23, 59, 59),
    )
  end

  let(:first_balance_event) do
    instance_double(
      QuotaBalanceEvent,
      class: instance_double(Class, name: 'QuotaBalanceEvent'),
      occurrence_timestamp: Time.utc(2025, 5, 27, 0, 0, 0),
      new_balance: 400,
      old_balance: 600,
    )
  end

  let(:second_balance_event) do
    instance_double(
      QuotaBalanceEvent,
      class: instance_double(Class, name: 'QuotaBalanceEvent'),
      occurrence_timestamp: Time.utc(2025, 5, 28, 0, 0, 0),
      new_balance: 300,
      old_balance: 400,
    )
  end

  let(:models) { [quota_definition, first_balance_event, second_balance_event] }

  describe '.heading' do
    it 'includes old and new balance columns' do
      expect(described_class.heading).to eq(
        [
          'Action',
          'Quota order number',
          'Balance updates',
          'Old Quota Balance',
          'New Quota Balance',
          'Sample commodities',
          'SID',
          'Critical state',
          'Critical threshold',
          'Initial volume',
          'Volume',
          'Maximum precision',
          'Start date',
          'End date',
        ],
      )
    end
  end

  describe '#data_row' do
    let!(:measures) do
      create_list(:measure, 5, :with_quota_definition, quota_definition_sid: 111, ordernumber: '123456')
    end

    it 'returns a correctly formatted data row' do
      row = mapper.data_row

      expect(row[0]).to eq('Create a new definition')
      expect(row[1]).to eq('123456')
      expect(row[6]).to eq(111)
      expect(row[7]).to eq('Y')
      expect(row[8]).to eq(50)
      expect(row[9]).to eq(1000)
      expect(row[10]).to eq(500)
      expect(row[11]).to eq(2)
      expect(row[12]).to eq('01/01/2025')
      expect(row[13]).to eq('31/12/2025')
    end

    it 'uses the last balance event values' do
      row = mapper.data_row

      expect(row[2]).to eq('2025-05-28')
      expect(row[3]).to eq(400)
      expect(row[4]).to eq(300)
    end

    it 'joins comm codes into a comma-separated string' do
      row = mapper.data_row
      expect(row[5]).to eq(measures.map(&:goods_nomenclature_item_id).uniq.sort.join(','))
    end

    context 'without quota balance events' do
      let(:models) { [quota_definition] }

      it 'leaves balance columns empty' do
        row = mapper.data_row

        expect(row[2]).to eq('')
        expect(row[3]).to eq('')
        expect(row[4]).to eq('')
      end
    end
  end
end
