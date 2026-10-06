RSpec.describe 'tariff:evaluation:compare_runs rake task' do
  let(:run) { create(:evaluation_run, question_model: 'bedrock/gpt-5.6-luna') }

  before do
    create(:evaluation_result, evaluation_run: run, latency_seconds: 1.5, gold_in_top1: true, gold_in_top5: true, cost_usd: 0.004, provider_calls: 2)
  end

  after { Rake::Task['tariff:evaluation:compare_runs'].reenable }

  around do |example|
    original = ENV['RUN_IDS']
    example.run
  ensure
    original ? ENV['RUN_IDS'] = original : ENV.delete('RUN_IDS')
  end

  it 'prints a markdown row for each run' do
    ENV['RUN_IDS'] = run.id.to_s

    expect { Rake::Task['tariff:evaluation:compare_runs'].invoke }
      .to output(/\| #{run.id} \| bedrock\/gpt-5\.6-luna \| Bedrock \| 1 \| 0 \| 100\.0 \| 100\.0 \| 1\.5 \| 1\.5 \| 2\.0 \| 4\.0 \| 4\.0 \|/).to_stdout
  end

  it 'aborts without RUN_IDS' do
    ENV.delete('RUN_IDS')

    expect { suppress_output { Rake::Task['tariff:evaluation:compare_runs'].invoke } }.to raise_error(SystemExit)
  end
end
