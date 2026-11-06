# frozen_string_literal: true

# These specs stop the replication settings drifting away from the schema. They read files only;
# spec/bin/database_replication_integration_spec.rb checks the behaviour against real PostgreSQL.
RSpec.describe 'database replication configuration' do
  def bash_array(name)
    Rails.root.join('bin/db-replicate').read[/^#{name}=\(\n(.*?)\n\)/m, 1].split
  end

  def structure
    Rails.root.join('db/structure.sql').read
  end

  def foreign_keys
    structure.scan(/ALTER TABLE ONLY (\S+)\s+ADD CONSTRAINT \S+ FOREIGN KEY \([^)]*\) REFERENCES (\S+?)\(/)
  end

  it 'keeps every evaluation table in the schema, plus the table they depend on' do
    evaluation_tables = structure.scan(/^CREATE TABLE (uk\.evaluation_\w+) \(/).flatten

    expect(evaluation_tables).not_to be_empty
    expect(bash_array('REPLICATION_EXCLUDED_TABLES')).to contain_exactly(*evaluation_tables, 'uk.tariff_knowledge_synthetic_atars')
  end

  it 'only keeps tables that reference each other, because the restore drops the rest of the schema around them' do
    kept = bash_array('REPLICATION_EXCLUDED_TABLES')
    crossing = foreign_keys.reject { |from, to| kept.include?(from) == kept.include?(to) }

    expect(crossing).to be_empty, "foreign keys between a kept table and another table: #{crossing.inspect}"
  end

  it 'preserves the local state of exactly the migrations that touch the kept tables' do
    table_names = bash_array('REPLICATION_EXCLUDED_TABLES').map { |table| table.split('.').last }

    touching_kept_tables = Rails.root.glob('db/migrate/*.rb').select { |file|
      source = file.read
      table_names.any? { |table| source.include?(table) }
    }.map { |file| file.basename.to_s }

    expect(bash_array('REPLICATION_EXCLUDED_MIGRATIONS')).to match_array(touching_kept_tables)
  end
end
