RSpec.describe 'Test database rake tasks' do
  describe 'db:test:populate_empty_materialized_views', :truncation do
    it 'refreshes dependencies through ordinary views before dependent materialized views' do
      db = Sequel::Model.db
      db.run('CREATE SCHEMA analytics_refresh_order_spec')
      db.run('CREATE TABLE analytics_refresh_order_spec.source (id integer PRIMARY KEY)')
      db[Sequel.qualify(:analytics_refresh_order_spec, :source)].insert(id: 1)
      db.run('CREATE MATERIALIZED VIEW analytics_refresh_order_spec.z_parent AS SELECT id FROM analytics_refresh_order_spec.source WITH NO DATA')
      db.run('CREATE VIEW analytics_refresh_order_spec.bridge AS SELECT id FROM analytics_refresh_order_spec.z_parent')
      db.run('CREATE MATERIALIZED VIEW analytics_refresh_order_spec.a_child AS SELECT id FROM analytics_refresh_order_spec.bridge WITH NO DATA')

      task = Rake::Task['db:test:populate_empty_materialized_views']
      task.reenable
      task.invoke

      expect(db.fetch('SELECT id FROM analytics_refresh_order_spec.a_child').all).to eq([{ id: 1 }])
    ensure
      db&.run('DROP SCHEMA IF EXISTS analytics_refresh_order_spec CASCADE')
    end
  end

  describe 'db:test:prepare_parallel' do
    subject(:prepare_parallel) { Rake::Task['db:test:prepare_parallel'].invoke }

    let(:prepare_command) { %w[bundle exec rails db:drop db:create db:structure:load] }

    around do |example|
      env_keys = %w[PARALLEL_TEST_PROCESSORS PARALLEL_TEST_PREPARE_VERBOSE]
      original_env = env_keys.index_with { |key| [ENV.key?(key), ENV[key]] }
      env_keys.each { |key| ENV.delete(key) }

      example.run
    ensure
      original_env.each do |key, (present, value)|
        present ? ENV[key] = value : ENV.delete(key)
      end
      Rake::Task['db:test:prepare_parallel'].reenable
    end

    context 'when PARALLEL_TEST_PROCESSORS is less than 1' do
      before { ENV['PARALLEL_TEST_PROCESSORS'] = '0' }

      it 'raises an error' do
        allow(Open3).to receive(:capture3)

        expect { prepare_parallel }.to raise_error('PARALLEL_TEST_PROCESSORS must be at least 1')
        expect(Open3).not_to have_received(:capture3)
      end
    end

    context 'with two worker databases' do
      before do
        ENV['PARALLEL_TEST_PROCESSORS'] = '2'
        allow(Open3).to receive(:capture3).and_return(['', '', successful_status])
      end

      it 'prepares each worker database' do
        expect { prepare_parallel }.to output(<<~OUTPUT).to_stdout
          Preparing test databases...
          Prepared tariff_test
          Prepared tariff_test2
        OUTPUT

        expect(Open3).to have_received(:capture3).with(
          { 'RAILS_ENV' => 'test', 'TEST_ENV_NUMBER' => '' },
          *prepare_command,
        ).ordered
        expect(Open3).to have_received(:capture3).with(
          { 'RAILS_ENV' => 'test', 'TEST_ENV_NUMBER' => '2' },
          *prepare_command,
        ).ordered
      end
    end

    context 'without PARALLEL_TEST_PROCESSORS' do
      it 'prepares five worker databases' do
        allow(Open3).to receive(:capture3).and_return(['', '', successful_status])

        suppress_output { prepare_parallel }

        expect(Open3).to have_received(:capture3).exactly(5).times
        expect(Open3).to have_received(:capture3).with(
          { 'RAILS_ENV' => 'test', 'TEST_ENV_NUMBER' => '' },
          *prepare_command,
        )
        expect(Open3).to have_received(:capture3).with(
          { 'RAILS_ENV' => 'test', 'TEST_ENV_NUMBER' => '5' },
          *prepare_command,
        )
      end
    end

    context 'when a worker database fails to prepare' do
      before { ENV['PARALLEL_TEST_PROCESSORS'] = '2' }

      it 'aborts with the database name' do
        failure = instance_double(Process::Status, success?: false)
        allow(Open3).to receive(:capture3).and_return(['drop failed', 'db error', failure])

        expect { prepare_parallel }
          .to raise_error(SystemExit, 'Failed to prepare tariff_test')
          .and output("Preparing test databases...\ndrop failed\n").to_stdout
          .and output("db error\nFailed to prepare tariff_test\n").to_stderr
        expect(Open3).to have_received(:capture3).once
      end
    end

    context 'when verbose output is enabled' do
      before do
        ENV['PARALLEL_TEST_PROCESSORS'] = '1'
        ENV['PARALLEL_TEST_PREPARE_VERBOSE'] = 'true'
      end

      it 'prints the command output' do
        allow(Open3).to receive(:capture3).and_return(["created\n", "warning\n", successful_status])

        expect { prepare_parallel }.to output(<<~OUTPUT).to_stdout.and output("warning\n").to_stderr
          Preparing test databases...
          created
          Prepared tariff_test
        OUTPUT
      end
    end

    def successful_status
      instance_double(Process::Status, success?: true)
    end
  end
end
