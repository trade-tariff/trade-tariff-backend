RSpec.describe EvaluationGoldQuerySet do
  describe 'validations' do
    subject(:gold_query_set) { build(:evaluation_gold_query_set, **attrs) }

    let(:attrs) { {} }

    it 'is valid with the factory defaults' do
      expect(gold_query_set).to be_valid
    end

    %i[name requested_size atar_percentage planned_count status].each do |column|
      context "when #{column} is missing" do
        let(:attrs) { { column => nil } }

        it 'is invalid' do
          expect(gold_query_set).not_to be_valid
          expect(gold_query_set.errors[column]).to be_present
        end
      end
    end

    context 'when the name is already used' do
      before { create(:evaluation_gold_query_set, name: 'Set A') }

      let(:attrs) { { name: 'Set A' } }

      it 'is invalid' do
        expect(gold_query_set).not_to be_valid
        expect(gold_query_set.errors[:name]).to include('is already taken')
      end
    end

    it 'accepts the largest allowed size' do
      expect(build(:evaluation_gold_query_set, requested_size: described_class::MAX_SIZE)).to be_valid
    end

    [0, 501, -3].each do |size|
      context "when the size is #{size}" do
        let(:attrs) { { requested_size: size } }

        it 'is invalid, with a message that names the limits' do
          expect(gold_query_set).not_to be_valid
          expect(gold_query_set.errors[:requested_size]).to eq(['must be between 1 and 500'])
        end
      end
    end

    [0, 100].each do |percentage|
      it "accepts an ATaR percentage of #{percentage}" do
        expect(build(:evaluation_gold_query_set, atar_percentage: percentage)).to be_valid
      end
    end

    [-1, 101].each do |percentage|
      context "when the ATaR percentage is #{percentage}" do
        let(:attrs) { { atar_percentage: percentage } }

        it 'is invalid' do
          expect(gold_query_set).not_to be_valid
          expect(gold_query_set.errors[:atar_percentage]).to eq(['must be between 0 and 100'])
        end
      end
    end

    context 'when the status is not one of the known statuses' do
      let(:attrs) { { status: 'stuck' } }

      it 'is invalid' do
        expect(gold_query_set).not_to be_valid
        expect(gold_query_set.errors[:status]).to be_present
      end
    end
  end

  describe 'defaults' do
    subject(:gold_query_set) { create(:evaluation_gold_query_set).reload }

    it 'starts with no progress and no failures' do
      expect(gold_query_set).to have_attributes(generated_count: 0, failed_count: 0, failures: [])
    end
  end

  describe '.record_item_result' do
    let(:gold_query_set) { create(:evaluation_gold_query_set, planned_count: 3, status: 'generating') }

    def failure(source_id)
      { 'source_type' => 'atar', 'source_id' => source_id, 'error' => 'no acceptable phrases' }
    end

    it 'counts a generated item and keeps generating until every planned item has finished' do
      described_class.record_item_result(gold_query_set.id)

      expect(gold_query_set.reload).to have_attributes(generated_count: 1, failed_count: 0, status: 'generating')
    end

    it 'counts a failed item, keeps the failure and keeps generating' do
      described_class.record_item_result(gold_query_set.id, failure: failure('600000001'))

      expect(gold_query_set.reload).to have_attributes(generated_count: 0, failed_count: 1, status: 'generating')
      expect(gold_query_set.failures.to_a.map(&:to_h)).to eq([failure('600000001')])
    end

    it 'becomes ready when every item generated' do
      3.times { described_class.record_item_result(gold_query_set.id) }

      expect(gold_query_set.reload).to have_attributes(generated_count: 3, failed_count: 0, status: 'ready')
    end

    it 'becomes partly_failed when some items failed' do
      2.times { described_class.record_item_result(gold_query_set.id) }
      described_class.record_item_result(gold_query_set.id, failure: failure('600000003'))

      expect(gold_query_set.reload).to have_attributes(generated_count: 2, failed_count: 1, status: 'partly_failed')
    end

    it 'becomes failed when every item failed, and lists every failure in order' do
      %w[600000001 600000002 600000003].each { |id| described_class.record_item_result(gold_query_set.id, failure: failure(id)) }

      expect(gold_query_set.reload).to have_attributes(generated_count: 0, failed_count: 3, status: 'failed')
      expect(gold_query_set.failures.to_a.map { |entry| entry['source_id'] }).to eq(%w[600000001 600000002 600000003])
    end

    it 'does nothing for a set that no longer exists' do
      expect(described_class.record_item_result(999_999)).to eq(0)
    end

    it 'adds to the counters stored in the database, not to a stale copy in memory' do
      stale = described_class[gold_query_set.id]
      described_class.record_item_result(gold_query_set.id)
      described_class.record_item_result(gold_query_set.id)

      described_class.record_item_result(stale.id)

      expect(gold_query_set.reload.generated_count).to eq(3)
    end
  end

  describe 'gold queries' do
    let(:gold_query_set) { create(:evaluation_gold_query_set) }

    it 'owns its gold queries and deletes them with the set' do
      create_list(:evaluation_gold_query, 2, evaluation_gold_query_set: gold_query_set)
      other_set_query = create(:evaluation_gold_query)

      expect(gold_query_set.evaluation_gold_queries.size).to eq(2)
      expect { gold_query_set.destroy }.to change(EvaluationGoldQuery, :count).by(-2)
      expect(EvaluationGoldQuery[other_set_query.id]).to be_present
    end
  end

  describe 'experiments' do
    it 'cannot be deleted while an experiment uses it' do
      gold_query_set = create(:evaluation_gold_query_set)
      create(:evaluation_experiment, gold_query_set_id: gold_query_set.id)

      expect { gold_query_set.destroy }.to raise_error(Sequel::ForeignKeyConstraintViolation)
      expect(described_class[gold_query_set.id]).to be_present
    end
  end
end
