RSpec.describe Api::Internal::QueryProcessing do
  let(:test_class) do
    Class.new do
      include Api::Internal::QueryProcessing
      public :process_query, :parse_date
    end
  end

  let(:instance) { test_class.new }

  describe '#process_query' do
    it 'returns empty string for blank input' do
      expect(instance.process_query(nil)).to eq('')
      expect(instance.process_query('')).to eq('')
    end

    it 'truncates to 100 characters' do
      long_query = 'a' * 200
      expect(instance.process_query(long_query).length).to eq(100)
    end

    it 'extracts CAS number from query' do
      expect(instance.process_query('cas 10310-21-1')).to eq('10310-21-1')
    end

    it 'extracts bare CAS number' do
      expect(instance.process_query('10310-21-1')).to eq('10310-21-1')
    end

    it 'preserves CUS number format' do
      expect(instance.process_query('0154438-3')).to eq('0154438-3')
    end

    it 'joins digits for numeric-only queries' do
      expect(instance.process_query('01 02')).to eq('0102')
    end

    it 'returns empty string for non-alpha non-digit input' do
      expect(instance.process_query('!@#')).to eq('')
    end

    it 'strips square brackets from text queries' do
      expect(instance.process_query('[hello] world')).to eq('hello world')
    end

    it 'passes through normal text queries' do
      expect(instance.process_query('horse')).to eq('horse')
    end
  end

  describe '#parse_date' do
    it 'returns today for blank input' do
      expect(instance.parse_date(nil)).to eq(Time.zone.today)
      expect(instance.parse_date('')).to eq(Time.zone.today)
    end

    it 'parses a valid date string' do
      expect(instance.parse_date('2024-06-15')).to eq(Date.new(2024, 6, 15))
    end

    it 'returns today for invalid date string' do
      expect(instance.parse_date('not-a-date')).to eq(Time.zone.today)
    end
  end
end
