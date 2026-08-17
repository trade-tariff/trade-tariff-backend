# spec/lib/tasks/evaluation_gold_queries_rake_spec.rb
require 'rails_helper'

RSpec.describe 'tariff:evaluation:generate_gold_queries rake task' do
  after { Rake::Task['tariff:evaluation:generate_gold_queries'].reenable }

  around do |example|
    names = %w[RESET LIMIT]
    original_values = names.index_with { |name| [ENV.key?(name), ENV[name]] }
    names.each { |name| ENV.delete(name) }

    example.run
  ensure
    original_values.each do |name, (present, value)|
      present ? ENV[name] = value : ENV.delete(name)
    end
  end

  it 'generates gold queries only for ATaRs missing at least one persona' do
    complete = create(:tariff_knowledge_public_atar_ruling, ref: '600000001')
    incomplete = create(:tariff_knowledge_public_atar_ruling, ref: '600000002')
    %w[emu_generic emu_ordinary emu_specific].each do |persona|
      create(:evaluation_gold_query, source_type: 'atar', source_id: complete.ref, persona:)
    end
    create(:evaluation_gold_query, source_type: 'atar', source_id: incomplete.ref, persona: 'emu_generic')

    allow(Evaluation::GoldQueryGenerator).to receive(:call) do |ruling|
      { 'generic' => 'x', 'ordinary' => 'y', 'specific' => 'z' }.tap do
        %w[emu_generic emu_ordinary emu_specific].each do |persona|
          EvaluationGoldQuery.dataset.insert_conflict(target: EvaluationGoldQuery::IDENTITY_COLUMNS).insert(
            source_type: 'atar', source_id: ruling.ref, persona:, query: 'x', expected_code: '0000000000',
          )
        end
      end
    end

    suppress_output { Rake::Task['tariff:evaluation:generate_gold_queries'].invoke }

    expect(Evaluation::GoldQueryGenerator).to have_received(:call).once.with(incomplete)
    expect(Evaluation::GoldQueryGenerator).not_to have_received(:call).with(complete)
  end

  it 'treats an ATaR with a deactivated persona row as incomplete, regenerates it, and reactivates the row' do
    ruling = create(:tariff_knowledge_public_atar_ruling, ref: '600000010')
    %w[emu_generic emu_ordinary].each do |persona|
      create(:evaluation_gold_query, source_type: 'atar', source_id: ruling.ref, persona:)
    end
    create(:evaluation_gold_query, source_type: 'atar', source_id: ruling.ref, persona: 'emu_specific', active: false, query: 'stale')
    allow(Evaluation::GoldQueryGenerator).to receive(:call) do |r|
      { 'generic' => 'x', 'ordinary' => 'y', 'specific' => 'z' }.tap do
        EvaluationGoldQuery.dataset.insert_conflict(
          target: EvaluationGoldQuery::IDENTITY_COLUMNS,
          update: { query: Sequel[:excluded][:query], active: true },
          update_where: { Sequel[:evaluation_gold_queries][:active] => false },
        ).insert(source_type: 'atar', source_id: r.ref, persona: 'emu_specific', query: 'z', expected_code: '0000000000')
      end
    end

    suppress_output { Rake::Task['tariff:evaluation:generate_gold_queries'].invoke }

    expect(Evaluation::GoldQueryGenerator).to have_received(:call).once.with(ruling)
    row = EvaluationGoldQuery.where(source_type: 'atar', source_id: ruling.ref, persona: 'emu_specific').first
    expect(row.active).to be(true)
    expect(row.query).to eq('z')
  end

  it 'treats an ATaR with an unexpected persona value as incomplete, even with 3+ active rows' do
    ruling = create(:tariff_knowledge_public_atar_ruling, ref: '600000025')
    %w[emu_generic emu_ordinary unexpected_persona].each do |persona|
      create(:evaluation_gold_query, source_type: 'atar', source_id: ruling.ref, persona:)
    end
    allow(Evaluation::GoldQueryGenerator).to receive(:call).and_return(
      { 'generic' => 'x', 'ordinary' => 'y', 'specific' => 'z' },
    )

    suppress_output { Rake::Task['tariff:evaluation:generate_gold_queries'].invoke }

    expect(Evaluation::GoldQueryGenerator).to have_received(:call).once.with(ruling)
  end

  it 'caps the number of ATaRs processed when LIMIT is set' do
    create(:tariff_knowledge_public_atar_ruling, ref: '600000011')
    create(:tariff_knowledge_public_atar_ruling, ref: '600000012')
    create(:tariff_knowledge_public_atar_ruling, ref: '600000013')
    allow(Evaluation::GoldQueryGenerator).to receive(:call).and_return(
      { 'generic' => 'x', 'ordinary' => 'y', 'specific' => 'z' },
    )

    ENV['LIMIT'] = '2'
    suppress_output { Rake::Task['tariff:evaluation:generate_gold_queries'].invoke }

    expect(Evaluation::GoldQueryGenerator).to have_received(:call).exactly(2).times
  end

  it 'aborts when every ATaR fails gold query generation and the minimum sample size is met' do
    create(:tariff_knowledge_public_atar_ruling, ref: '600000014')
    create(:tariff_knowledge_public_atar_ruling, ref: '600000015')
    create(:tariff_knowledge_public_atar_ruling, ref: '600000016')
    allow(Evaluation::GoldQueryGenerator).to receive(:call).and_return(nil)

    expect {
      suppress_output { Rake::Task['tariff:evaluation:generate_gold_queries'].invoke }
    }.to raise_error(SystemExit, /All 3 ATaRs failed gold query generation/)
  end

  it 'does not abort on a LIMIT=1 smoke test that hits an ordinary content rejection' do
    create(:tariff_knowledge_public_atar_ruling, ref: '600000017')
    create(:tariff_knowledge_public_atar_ruling, ref: '600000018')
    allow(Evaluation::GoldQueryGenerator).to receive(:call).and_return(nil)

    ENV['LIMIT'] = '1'

    expect {
      suppress_output { Rake::Task['tariff:evaluation:generate_gold_queries'].invoke }
    }.not_to raise_error
  end

  it 'does not abort on a LIMIT=2 smoke test that hits an ordinary content rejection' do
    create(:tariff_knowledge_public_atar_ruling, ref: '600000019')
    create(:tariff_knowledge_public_atar_ruling, ref: '600000020')
    create(:tariff_knowledge_public_atar_ruling, ref: '600000021')
    allow(Evaluation::GoldQueryGenerator).to receive(:call).and_return(nil)

    ENV['LIMIT'] = '2'

    expect {
      suppress_output { Rake::Task['tariff:evaluation:generate_gold_queries'].invoke }
    }.not_to raise_error
  end

  it 'raises a clear error when LIMIT is 0' do
    ENV['LIMIT'] = '0'

    expect {
      suppress_output { Rake::Task['tariff:evaluation:generate_gold_queries'].invoke }
    }.to raise_error(ArgumentError, 'LIMIT must be a positive integer')
  end

  it 'raises a clear error when LIMIT is negative' do
    ENV['LIMIT'] = '-1'

    expect {
      suppress_output { Rake::Task['tariff:evaluation:generate_gold_queries'].invoke }
    }.to raise_error(ArgumentError, 'LIMIT must be a positive integer')
  end

  it 'processes a deterministic subset ordered by ref when LIMIT is set' do
    create(:tariff_knowledge_public_atar_ruling, ref: '600000024')
    create(:tariff_knowledge_public_atar_ruling, ref: '600000022')
    create(:tariff_knowledge_public_atar_ruling, ref: '600000023')
    processed_refs = []
    allow(Evaluation::GoldQueryGenerator).to receive(:call) do |ruling|
      processed_refs << ruling.ref
      { 'generic' => 'x', 'ordinary' => 'y', 'specific' => 'z' }
    end

    ENV['LIMIT'] = '2'
    suppress_output { Rake::Task['tariff:evaluation:generate_gold_queries'].invoke }

    expect(processed_refs).to eq(%w[600000022 600000023])
  end

  it 'wipes and regenerates every ATaR when RESET=true' do
    existing = create(:tariff_knowledge_public_atar_ruling, ref: '600000003')
    %w[emu_generic emu_ordinary emu_specific].each do |persona|
      create(:evaluation_gold_query, source_type: 'atar', source_id: existing.ref, persona:)
    end
    allow(Evaluation::GoldQueryGenerator).to receive(:call).and_return(
      { 'generic' => 'x', 'ordinary' => 'y', 'specific' => 'z' },
    )

    ENV['RESET'] = 'true'
    suppress_output { Rake::Task['tariff:evaluation:generate_gold_queries'].invoke }

    expect(EvaluationGoldQuery.count).to eq(0)
    expect(Evaluation::GoldQueryGenerator).to have_received(:call).once.with(existing)
  end

  it 'continues to the next ATaR when one fails' do
    first = create(:tariff_knowledge_public_atar_ruling, ref: '600000004')
    second = create(:tariff_knowledge_public_atar_ruling, ref: '600000005')
    allow(Evaluation::GoldQueryGenerator).to receive(:call).with(first).and_return(nil)
    allow(Evaluation::GoldQueryGenerator).to receive(:call).with(second).and_return(
      { 'generic' => 'x', 'ordinary' => 'y', 'specific' => 'z' },
    )

    suppress_output { Rake::Task['tariff:evaluation:generate_gold_queries'].invoke }

    expect(Evaluation::GoldQueryGenerator).to have_received(:call).with(first)
    expect(Evaluation::GoldQueryGenerator).to have_received(:call).with(second)
  end

  it 'rescues exceptions and continues to the next ATaR' do
    first = create(:tariff_knowledge_public_atar_ruling, ref: '600000006')
    second = create(:tariff_knowledge_public_atar_ruling, ref: '600000007')
    allow(Evaluation::GoldQueryGenerator).to receive(:call).with(first).and_raise(StandardError.new('boom'))
    allow(Evaluation::GoldQueryGenerator).to receive(:call).with(second) do |ruling|
      { 'generic' => 'x', 'ordinary' => 'y', 'specific' => 'z' }.tap do
        %w[emu_generic emu_ordinary emu_specific].each do |persona|
          EvaluationGoldQuery.dataset.insert_conflict(target: EvaluationGoldQuery::IDENTITY_COLUMNS).insert(
            source_type: 'atar', source_id: ruling.ref, persona:, query: 'x', expected_code: '0000000000',
          )
        end
      end
    end
    allow(Rails.logger).to receive(:warn)

    suppress_output { Rake::Task['tariff:evaluation:generate_gold_queries'].invoke }

    expect(Evaluation::GoldQueryGenerator).to have_received(:call).with(first)
    expect(Evaluation::GoldQueryGenerator).to have_received(:call).with(second)
    expect(Rails.logger).to have_received(:warn).with(/Failed to generate evaluation gold queries for ATaR 600000006/)
  end
end
