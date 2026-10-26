# frozen_string_literal: true

require 'yaml'

# These specs stop the replication settings drifting away from the schema. They read files only;
# spec/bin/database_replication_integration_spec.rb checks the behaviour against real PostgreSQL.
RSpec.describe 'database replication configuration' do
  def filter_tables
    Rails.root.join('config/database-replication.filter').read.lines.filter_map do |line|
      line.strip[/\Aexclude table (\S+)\z/, 1]
    end
  end

  def excluded_migrations
    Rails.root.join('bin/db-replicate').read[/REPLICATION_EXCLUDED_MIGRATIONS=\(\n(.*?)\n\)/m, 1].split
  end

  it 'excludes every evaluation table in the schema, plus the table they depend on' do
    evaluation_tables = Rails.root.join('db/structure.sql').read.scan(/^CREATE TABLE (uk\.evaluation_\w+) \(/).flatten

    expect(evaluation_tables).not_to be_empty
    expect(filter_tables).to contain_exactly(*evaluation_tables, 'uk.tariff_knowledge_synthetic_atars')
  end

  it 'preserves the local state of exactly the migrations that touch the excluded tables' do
    table_names = filter_tables.map { |table| table.split('.').last }

    touching_excluded_tables = Rails.root.glob('db/migrate/*.rb').select { |file|
      source = file.read
      table_names.any? { |table| source.include?(table) }
    }.map { |file| file.basename.to_s }

    expect(excluded_migrations).to match_array(touching_excluded_tables)
  end

  %w[staging development].each do |environment|
    it "restores the replication archive, not the full backup, in the #{environment} workflow" do
      workflow = YAML.safe_load_file(Rails.root.join(".github/workflows/replicate-db-#{environment}.yml"))
      run_task = workflow.dig('jobs', 'run-job', 'steps').find { |step| step['name'] == 'Run ECS task' }

      expect(run_task['run']).to match(
        %r{"name":\s*"RESTORE_FILE",\s*"value":\s*"/tariff-merged-production\.replication\.dump"},
      )
    end
  end
end
