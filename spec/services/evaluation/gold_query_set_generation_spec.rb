# Runs the whole chain that Sidekiq would run, one step after another and without Redis:
# create the set, run the coordinator job, run every item job, then read the result back
# through the internal API the eval app uses.
RSpec.describe 'Generating a gold query set from start to finish', type: :request do
  let(:ai_client) { instance_double(OpenaiClient) }
  let(:tiers) { { 'generic' => 'food box', 'ordinary' => 'plastic food container', 'specific' => 'plastic lunch box with clip lid' } }
  let(:coordinator_jobs) { [] }
  let(:item_jobs) { [] }

  # Pretends to be Sidekiq: keeps the arguments, so each job can be run explicitly.
  def run_all_jobs
    coordinator_jobs.each { |args| GenerateGoldQuerySetWorker.new.perform(*args) }
    item_jobs.each { |args| GenerateGoldQueryItemWorker.new.perform(*args) }
  end

  before do
    allow(TradeTariffBackend).to receive(:ai_client).and_return(ai_client)
    allow(ai_client).to receive(:call).and_return(tiers)
    allow(GenerateGoldQuerySetWorker).to receive(:perform_async) { |*args| coordinator_jobs << args }
    allow(GenerateGoldQueryItemWorker).to receive(:perform_bulk) { |jobs| item_jobs.concat(jobs) }

    create_list(:tariff_knowledge_public_atar_ruling, 2)
    create(:tariff_knowledge_synthetic_atar, description: 'First synthetic description')
    create(:tariff_knowledge_synthetic_atar, description: 'Second synthetic description')
  end

  def create_set(size: 4, percentage: 50)
    Evaluation::GoldQuerySetCreator.call(name: 'Set A', requested_size: size, atar_percentage: percentage, created_by: 'user-123')
  end

  it 'ends with a ready set that holds 3 gold queries per item, with history' do
    set = create_set
    run_all_jobs

    expect(set.reload).to have_attributes(status: 'ready', planned_count: 4, generated_count: 4, failed_count: 0, failures: [])
    rows = EvaluationGoldQuery.where(set_id: set.id).all
    expect(rows.size).to eq(12)
    expect(rows.map(&:source_type).tally).to eq('atar' => 6, 'synthetic_atar' => 6)
    expect(rows.map { |row| row.versions.map(&:event) }.uniq).to eq([%w[create]])
    expect(rows.flat_map { |row| row.versions.map(&:whodunnit) }.uniq).to eq(%w[user-123])
  end

  it 'gives the eval app every row of the set, each with its own oracle text, and none of another set' do
    other_set = create(:evaluation_gold_query_set)
    create(:evaluation_gold_query, evaluation_gold_query_set: other_set)
    set = create_set
    run_all_jobs

    get '/uk/internal/evaluation_gold_queries.json', params: { set_id: set.id, per_page: 250 }

    rows = response.parsed_body['data'].pluck('attributes')
    expect(rows.size).to eq(12)
    expect(rows.pluck('set_id').uniq).to eq([set.id])
    expect(rows.pluck('oracle_text')).to all(be_present)
    expect(rows.select { |row| row['source_type'] == 'synthetic_atar' }.pluck('oracle_text').uniq)
      .to contain_exactly('First synthetic description', 'Second synthetic description')
  end

  it 'sends the real search only for the synthetic ATaRs' do
    user_messages = []
    allow(ai_client).to receive(:call) do |messages, **|
      user_messages << messages.last[:content]
      tiers
    end

    create_set
    run_all_jobs

    expect(user_messages.size).to eq(4)
    expect(user_messages.count { |message| message.start_with?('Real user search:') }).to eq(2)
    expect(user_messages.count { |message| message.start_with?('Description:') }).to eq(2)
  end

  it 'ends partly failed, listing the item that failed, when the model cannot write for one item' do
    bad = TariffKnowledge::SyntheticAtar.order(:id).first
    bad.update(real_user_search: 'unwritable search')
    allow(ai_client).to receive(:call) { |messages, **| messages.last[:content].include?('unwritable search') ? nil : tiers }

    set = create_set
    run_all_jobs

    expect(set.reload).to have_attributes(status: 'partly_failed', generated_count: 3, failed_count: 1)
    expect(set.failures.first.to_h).to include('source_type' => 'synthetic_atar', 'source_id' => bad.id.to_s)
    expect(EvaluationGoldQuery.where(set_id: set.id).count).to eq(9)
  end

  it 'ends failed when the model cannot write for any item' do
    allow(ai_client).to receive(:call).and_return(nil)

    set = create_set
    run_all_jobs

    expect(set.reload).to have_attributes(status: 'failed', generated_count: 0, failed_count: 4)
    expect(EvaluationGoldQuery.where(set_id: set.id).count).to eq(0)
  end

  it 'lets two sets contain the same source item without touching each other' do
    first = create_set(size: 2, percentage: 100)
    second = Evaluation::GoldQuerySetCreator.call(name: 'Set B', requested_size: 2, atar_percentage: 100, created_by: 'user-456')
    run_all_jobs

    expect([first.reload.status, second.reload.status]).to eq(%w[ready ready])
    expect(EvaluationGoldQuery.where(set_id: first.id).count).to eq(6)
    expect(EvaluationGoldQuery.where(set_id: second.id).count).to eq(6)
  end
end
