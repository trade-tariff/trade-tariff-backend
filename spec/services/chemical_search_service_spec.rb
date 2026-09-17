RSpec.describe ChemicalSearchService do
  describe '#perform' do
    subject(:results) { service.perform }

    let(:service) { described_class.new({ 'name' => 'acid' }, 1, 20) }
    let(:citric_acid) { create(:chemical) }
    let(:acetic_acid) { create(:chemical) }

    before do
      create(:chemical_name, chemical: citric_acid, name: 'citric acid')
      create(:chemical_name, chemical: citric_acid, name: 'citric acid monohydrate')
      create(:chemical_name, chemical: acetic_acid, name: 'acetic acid')
      create(:chemical_name, name: 'water')
    end

    it 'returns each matching chemical once' do
      expect(results).to contain_exactly(citric_acid, acetic_acid)
    end

    it 'loads the chemicals for all matching names in one query' do
      queries = sql_queries { results }

      expect(queries.count { |query| query.include?('FROM "chemicals"') }).to eq(1)
    end
  end

  def sql_queries
    queries = []
    logger = Logger.new(StringIO.new)
    logger.formatter = proc do |_severity, _datetime, _progname, message|
      queries << message
      nil
    end

    Sequel::Model.db.loggers << logger
    yield
    queries
  ensure
    Sequel::Model.db.loggers.delete(logger)
  end
end
