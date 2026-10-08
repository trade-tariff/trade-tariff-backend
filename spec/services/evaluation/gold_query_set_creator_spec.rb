RSpec.describe Evaluation::GoldQuerySetCreator do
  subject(:set) { described_class.call(name: 'Set A', requested_size: 10, atar_percentage: 50, created_by: 'user-123') }

  before { allow(GenerateGoldQuerySetWorker).to receive(:perform_async) }

  def queued_items
    queued = nil
    expect(GenerateGoldQuerySetWorker).to have_received(:perform_async) { |_set_id, items| queued = items }
    queued
  end

  def create_pools(atars:, synthetic_atars:)
    create_list(:tariff_knowledge_public_atar_ruling, atars)
    create_list(:tariff_knowledge_synthetic_atar, synthetic_atars)
  end

  context 'with enough source items in both pools' do
    before { create_pools(atars: 12, synthetic_atars: 12) }

    it 'saves a generating set that records who asked for it and how many items are planned' do
      expect(set).to have_attributes(
        name: 'Set A', requested_size: 10, atar_percentage: 50, planned_count: 10,
        generated_count: 0, failed_count: 0, status: 'generating', created_by: 'user-123'
      )
      expect(set.errors).to be_empty
      expect(EvaluationGoldQuerySet[set.id]).to be_present
    end

    it 'queues one coordinator job with the set id and the chosen items' do
      set

      expect(GenerateGoldQuerySetWorker).to have_received(:perform_async).once.with(set.id, an_instance_of(Array))
      expect(queued_items.size).to eq(10)
    end

    it 'picks round(size x percentage) real ATaRs and the rest synthetic ATaRs' do
      set

      expect(queued_items.map(&:first).tally).to eq('atar' => 5, 'synthetic_atar' => 5)
    end

    it 'picks each item at most once' do
      set

      expect(queued_items.uniq.size).to eq(10)
    end

    it 'names items the way the item worker expects: ATaR ref, and synthetic ATaR id as a string' do
      set

      atar_ids = queued_items.select { |type, _| type == 'atar' }.map(&:last)
      synthetic_ids = queued_items.select { |type, _| type == 'synthetic_atar' }.map(&:last)
      expect(atar_ids).to all(satisfy { |ref| TariffKnowledge::PublicAtarRuling.by_ref(ref).any? })
      expect(synthetic_ids).to all(satisfy { |id| id.is_a?(String) && TariffKnowledge::SyntheticAtar[id.to_i] })
    end

    it 'rounds a half up (25% of 10 is 3 ATaRs and 7 synthetic ATaRs)' do
      described_class.call(name: 'Set B', requested_size: 10, atar_percentage: 25, created_by: 'user-123')

      expect(queued_items.map(&:first).tally).to eq('atar' => 3, 'synthetic_atar' => 7)
    end

    it 'takes only real ATaRs at 100% and only synthetic ATaRs at 0%' do
      described_class.call(name: 'All ATaR', requested_size: 4, atar_percentage: 100, created_by: 'user-123')
      described_class.call(name: 'No ATaR', requested_size: 4, atar_percentage: 0, created_by: 'user-123')

      expect(GenerateGoldQuerySetWorker).to have_received(:perform_async).twice
      expect(EvaluationGoldQuerySet.where(name: ['All ATaR', 'No ATaR']).select_hash(:name, :planned_count)).to eq('All ATaR' => 4, 'No ATaR' => 4)
    end
  end

  context 'when a source has fewer items than asked for' do
    before { create_pools(atars: 2, synthetic_atars: 12) }

    it 'takes all of them, does not top up from the other source, and records the shortfall' do
      expect(set).to have_attributes(requested_size: 10, planned_count: 7)
      expect(queued_items.map(&:first).tally).to eq('atar' => 2, 'synthetic_atar' => 5)
    end
  end

  context 'when there are no source items at all' do
    it 'creates nothing, queues nothing, and says why' do
      expect(set.errors[:requested_size].first).to include('no ATaR rulings or synthetic ATaRs')
      expect(EvaluationGoldQuerySet.count).to eq(0)
      expect(GenerateGoldQuerySetWorker).not_to have_received(:perform_async)
    end
  end

  context 'when the input is invalid' do
    before { create_pools(atars: 3, synthetic_atars: 3) }

    it 'refuses a blank name' do
      invalid = described_class.call(name: '', requested_size: 4, atar_percentage: 50, created_by: 'user-123')

      expect(invalid.errors[:name]).to be_present
    end

    it 'refuses a size above the limit, with a message that names it' do
      invalid = described_class.call(name: 'Big', requested_size: 501, atar_percentage: 50, created_by: 'user-123')

      expect(invalid.errors[:requested_size]).to eq(['must be between 1 and 500'])
    end

    it 'refuses a percentage above 100' do
      invalid = described_class.call(name: 'Odd', requested_size: 4, atar_percentage: 120, created_by: 'user-123')

      expect(invalid.errors[:atar_percentage]).to eq(['must be between 0 and 100'])
    end

    it 'refuses a name that is already used' do
      create(:evaluation_gold_query_set, name: 'Set A')

      expect(set.errors[:name]).to include('is already taken')
    end

    it 'saves and queues nothing when the input is invalid' do
      described_class.call(name: '', requested_size: 4, atar_percentage: 50, created_by: 'user-123')

      expect(EvaluationGoldQuerySet.count).to eq(0)
      expect(GenerateGoldQuerySetWorker).not_to have_received(:perform_async)
    end

    it 'accepts a size and a percentage sent as text (as a form or query string would)' do
      text_set = described_class.call(name: 'Text', requested_size: '4', atar_percentage: '50', created_by: 'user-123')

      expect(text_set.errors).to be_empty
      expect(text_set.planned_count).to eq(4)
    end
  end

  context 'when queueing the job fails' do
    before do
      create_pools(atars: 3, synthetic_atars: 3)
      allow(GenerateGoldQuerySetWorker).to receive(:perform_async).and_raise(RedisClient::CannotConnectError, 'redis is down')
    end

    it 'removes the set again and raises, instead of leaving a set that can never finish' do
      expect { set }.to raise_error(RedisClient::CannotConnectError)
      expect(EvaluationGoldQuerySet.count).to eq(0)
    end
  end

  it 'queues the job only after the set has been saved' do
    create_pools(atars: 3, synthetic_atars: 3)
    saved_when_queued = nil
    allow(GenerateGoldQuerySetWorker).to receive(:perform_async) { |set_id, _items| saved_when_queued = EvaluationGoldQuerySet[set_id].present? }

    set

    expect(saved_when_queued).to be(true)
  end
end
