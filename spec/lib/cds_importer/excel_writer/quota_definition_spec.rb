RSpec.describe CdsImporter::ExcelWriter::QuotaDefinition do
  subject(:mapper) { described_class.new(models) }

  let(:quota_definition) do
    instance_double(
      :quota_definition,
      class: instance_double(name: 'QuotaDefinition'),
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

  let(:balance_event1) do
    instance_double(
      :quota_balance_event,
      class: instance_double(name: 'QuotaBalanceEvent'),
      occurrence_timestamp: Time.utc(2025, 5, 27, 0, 0, 0),
      new_balance: 400,
      old_balance: 600,
    )
  end

  let(:balance_event2) do
    instance_double(
      :quota_balance_event,
      class: instance_double(name: 'QuotaBalanceEvent'),
      occurrence_timestamp: Time.utc(2025, 5, 28, 0, 0, 0),
      new_balance: 300,
      old_balance: 400,
    )
  end

  let(:models) { [quota_definition, balance_event1, balance_event2] }

  describe '#data_row' do
    let!(:measures) do
      create_list(:measure, 5, :with_quota_definition, quota_definition_sid: 111, ordernumber: '123456')
    end

    it 'returns a correctly formatted data row' do
      row = mapper.data_row

      expect(row[0]).to eq('Create a new definition')
      expect(row[1]).to eq('123456')
      expect(row[4]).to eq(111)
      expect(row[5]).to eq('Y')
      expect(row[6]).to eq(50)
      expect(row[7]).to eq(1000)
      expect(row[8]).to eq(500)
      expect(row[9]).to eq(2)
      expect(row[10]).to eq('01/01/2025')
      expect(row[11]).to eq('31/12/2025')
    end

    it 'uses the last balance event string' do
      row = mapper.data_row
      expect(row[2]).to match(/2025-05-28 - New: 300 : Old: 400/)
    end

    it 'joins comm codes into a comma-separated string' do
      row = mapper.data_row
      expect(row[3]).to eq(measures.map(&:goods_nomenclature_item_id).join(','))
    end
  end
end
