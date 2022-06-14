TestSerializer = Struct.new('Serializer') do
  include Api::Shared::CsvSerializer

  columns :id, :numeral

  column :title, column_name: 'Flibble'
  column :chapter_to, column_name: 'Qux' do |serializable, _options|
    serializable.qux
  end
end

RSpec.describe Api::Shared::CsvSerializer do
  let(:serializables) do
    [
      Struct.new(:id, :numeral, :title, :qux).new(
        '123',
        'IV',
        'Thing is, good',
        'Smizmar',
      ),
    ]
  end

  describe '#serializable_array' do
    subject(:serializable_array) { TestSerializer.new(serializables).serializable_array }

    it { is_expected.to eq([[:id, :numeral, 'Flibble', 'Qux'], ['123', 'IV', 'Thing is, good', 'Smizmar']]) }
  end

  describe '#serialized_csv' do
    subject(:serialized_csv) { TestSerializer.new(serializables).serialized_csv }

    it { is_expected.to eq("id,numeral,Flibble,Qux\n123,IV,\"Thing is, good\",Smizmar\n") }
  end
end
