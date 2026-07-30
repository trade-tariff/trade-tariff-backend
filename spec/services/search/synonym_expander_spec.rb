RSpec.describe Search::SynonymExpander do
  let(:rules_path) { Rails.root.join('spec/fixtures/files/search_synonyms.txt') }

  it 'appends directional alternatives while preserving the original phrase' do
    query = 'Replacement HEPA filter unit'

    expect(described_class.call(query, rules_path:)).to eq('Replacement HEPA filter unit high efficiency particulate air filter')
  end

  it 'matches phrases case-insensitively' do
    query = 'replacement hepa FILTER'

    expect(described_class.call(query, rules_path:)).to eq('replacement hepa FILTER high efficiency particulate air filter')
  end

  it 'expands equivalent terms in either direction' do
    expect(described_class.call('TV stand', rules_path:)).to eq('TV stand television')
    expect(described_class.call('television stand', rules_path:)).to eq('television stand TV')
  end

  it 'matches only complete terms' do
    query = 'preHEPA filter unit'

    expect(described_class.call(query, rules_path:)).to eq(query)
  end

  it 'does not append an alternative already present in the query' do
    query = 'HEPA filter high efficiency particulate air filter'

    expect(described_class.call(query, rules_path:)).to eq(query)
  end

  it 'treats identity mappings as no-ops' do
    query = 'LED screen'

    expect(described_class.call(query, rules_path:)).to eq(query)
  end

  it 'rejects malformed directional rules with their line number' do
    invalid_rules_path = Rails.root.join('spec/fixtures/files/invalid_search_synonyms.txt')

    expect {
      described_class.call('HEPA filter', rules_path: invalid_rules_path)
    }.to raise_error(described_class::InvalidRule, /line 1/)
  end

  it 'loads the production rules file by default' do
    expect(described_class.call('replacement HEPA filter'))
      .to eq('replacement HEPA filter high efficiency particulate air filter')
  end

  describe 'reviewed production rules' do
    {
      'robotic vacum cleaner with mop function' =>
        'robotic vacum cleaner with mop function vacuum cleaner',
      'vermeil ring' =>
        'vermeil ring gold plated silver ring',
      'vermeil necklace' =>
        'vermeil necklace gold plated silver necklace',
      'Invisalign system comprehensive' =>
        'Invisalign system comprehensive clear dental aligner',
      'ClearCorrect aligner' =>
        'ClearCorrect aligner clear dental aligner',
      'Vivera retainers' =>
        'Vivera retainers orthodontic retainer orthopaedic appliance',
      'PTCA dilatation catheter' =>
        'PTCA dilatation catheter percutaneous transluminal coronary angioplasty catheter',
      'Cricut Joy Xtra' =>
        'Cricut Joy Xtra electronic cutting machine',
      'Denon Perl' =>
        'Denon Perl wireless earbuds',
      'Ledger Flex' =>
        'Ledger Flex hardware wallet',
    }.each do |query, expanded_query|
      it "expands #{query}" do
        expect(described_class.call(query)).to eq(expanded_query)
      end
    end
  end

  it 'parses each rules file once when requests initialise it concurrently' do
    source_class = Class.new do
      attr_reader :reads

      def initialize(path)
        @path = path
        @reads = 0
        @mutex = Mutex.new
      end

      def to_s
        'concurrent-search-synonyms'
      end

      def each_line
        @mutex.synchronize { @reads += 1 }
        sleep(0.01)
        @path.each_line
      end
    end
    rules_source = source_class.new(rules_path)
    ready = Queue.new
    start = Queue.new

    threads = Array.new(8) do
      Thread.new do
        ready << true
        start.pop
        described_class.call('HEPA filter', rules_path: rules_source)
      end
    end
    8.times { ready.pop }
    8.times { start << true }

    expect(threads.map(&:value)).to all(include('high efficiency particulate air filter'))
    expect(rules_source.reads).to eq(1)
  end
end
