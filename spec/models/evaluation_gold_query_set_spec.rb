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
