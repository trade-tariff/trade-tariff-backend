RSpec.describe 'tariff:evaluation:generate_gold_queries rake task' do
  before do
    allow(GenerateGoldQuerySetWorker).to receive(:perform_async)
    create_list(:tariff_knowledge_public_atar_ruling, 4)
    create_list(:tariff_knowledge_synthetic_atar, 4)
  end

  after { Rake::Task['tariff:evaluation:generate_gold_queries'].reenable }

  around do |example|
    names = %w[NAME SIZE ATAR_PERCENTAGE]
    original_values = names.index_with { |name| [ENV.key?(name), ENV[name]] }
    names.each { |name| ENV.delete(name) }

    example.run
  ensure
    original_values.each do |name, (present, value)|
      present ? ENV[name] = value : ENV.delete(name)
    end
  end

  def invoke
    suppress_output { Rake::Task['tariff:evaluation:generate_gold_queries'].invoke }
  end

  context 'with a name and a size' do
    before do
      ENV['NAME'] = 'Set A'
      ENV['SIZE'] = '3'
    end

    it 'creates a set of real ATaRs only by default, as the task always did' do
      invoke

      set = EvaluationGoldQuerySet.first(name: 'Set A')
      expect(set).to have_attributes(requested_size: 3, atar_percentage: 100, planned_count: 3, status: 'generating')
    end

    it 'records that the rake task created it' do
      invoke

      expect(EvaluationGoldQuerySet.first(name: 'Set A').created_by).to start_with('rake:')
    end

    it 'queues the background job through the same service as the admin API' do
      invoke

      expect(GenerateGoldQuerySetWorker).to have_received(:perform_async).once
        .with(EvaluationGoldQuerySet.first(name: 'Set A').id, satisfy { |items| items.size == 3 && items.all? { |type, _| type == 'atar' } })
    end

    it 'prints the set id and how to follow its progress' do
      expect { Rake::Task['tariff:evaluation:generate_gold_queries'].invoke }
        .to output(/Created gold query set \d+ \(Set A\): 3 items planned.*Sidekiq.*EvaluationGoldQuerySet\[\d+\]/m).to_stdout
    end

    it 'takes the ATaR percentage from ATAR_PERCENTAGE' do
      ENV['ATAR_PERCENTAGE'] = '50'
      ENV['SIZE'] = '4'

      invoke

      expect(EvaluationGoldQuerySet.first(name: 'Set A')).to have_attributes(atar_percentage: 50, planned_count: 4)
      expect(GenerateGoldQuerySetWorker).to have_received(:perform_async) { |_id, items| expect(items.map(&:first).tally).to eq('atar' => 2, 'synthetic_atar' => 2) }
    end
  end

  context 'when NAME is missing' do
    before { ENV['SIZE'] = '3' }

    it 'aborts and says so' do
      expect { Rake::Task['tariff:evaluation:generate_gold_queries'].invoke }
        .to raise_error(SystemExit).and output(/NAME is required/).to_stderr
      expect(EvaluationGoldQuerySet.count).to eq(0)
    end
  end

  context 'when SIZE is missing' do
    before { ENV['NAME'] = 'Set A' }

    it 'aborts and says so' do
      expect { Rake::Task['tariff:evaluation:generate_gold_queries'].invoke }
        .to raise_error(SystemExit).and output(/SIZE is required/).to_stderr
      expect(EvaluationGoldQuerySet.count).to eq(0)
    end
  end

  context 'when the input is refused' do
    it 'aborts with the reason and creates nothing when the size is too large' do
      ENV['NAME'] = 'Big'
      ENV['SIZE'] = '501'

      expect { Rake::Task['tariff:evaluation:generate_gold_queries'].invoke }
        .to raise_error(SystemExit).and output(/Gold query set not created: .*must be between 1 and 500/).to_stderr
      expect(EvaluationGoldQuerySet.count).to eq(0)
      expect(GenerateGoldQuerySetWorker).not_to have_received(:perform_async)
    end

    it 'refuses a name that is already used, so running the command twice cannot make two identical sets' do
      create(:evaluation_gold_query_set, name: 'Set A')
      ENV['NAME'] = 'Set A'
      ENV['SIZE'] = '3'

      expect { Rake::Task['tariff:evaluation:generate_gold_queries'].invoke }
        .to raise_error(SystemExit).and output(/is already taken/).to_stderr
      expect(EvaluationGoldQuerySet.count).to eq(1)
    end
  end
end
