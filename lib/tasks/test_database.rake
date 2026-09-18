require 'open3'

desc 'Populate empty materialized views after loading the test structure'
task 'db:test:populate_empty_materialized_views' => :environment do # rubocop:disable Metrics/BlockLength
  db = begin
    Sequel::Model.db
  rescue Sequel::Error
    Sequel.connect(Rails.application.config.database_configuration.fetch(Rails.env).symbolize_keys)
  end

  db.fetch(<<~SQL).each do |row|
    WITH RECURSIVE relations AS (
      SELECT c.oid, c.relkind, quote_ident(n.nspname) || '.' || quote_ident(c.relname) AS view_name
      FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE c.relkind IN ('v', 'm')
        AND n.nspname NOT IN ('pg_catalog', 'information_schema')
    ), dependencies AS (
      SELECT DISTINCT r.ev_class AS dependent, d.refobjid AS dependency
      FROM pg_rewrite r JOIN pg_depend d ON d.objid = r.oid
      JOIN relations parent ON parent.oid = d.refobjid
      WHERE d.classid = 'pg_rewrite'::regclass AND d.refclassid = 'pg_class'::regclass
        AND r.ev_class <> d.refobjid
    ), paths AS (
      SELECT oid AS root, oid AS dependency, ARRAY[oid] AS visited, 0 AS depth
      FROM relations WHERE relkind = 'm'
      UNION ALL
      SELECT p.root, d.dependency, p.visited || d.dependency, p.depth + 1
      FROM paths p JOIN dependencies d ON d.dependent = p.dependency
      WHERE NOT d.dependency = ANY(p.visited)
    )
    SELECT r.view_name FROM paths p JOIN relations r ON r.oid = p.root
    GROUP BY r.oid, r.view_name ORDER BY max(p.depth), r.view_name
  SQL
    db.run("REFRESH MATERIALIZED VIEW #{row[:view_name]}")
  end
end

desc 'Prepare parallel test databases'
task 'db:test:prepare_parallel' => :environment do
  workers = Integer(ENV.fetch('PARALLEL_TEST_PROCESSORS', 5))

  raise 'PARALLEL_TEST_PROCESSORS must be at least 1' if workers < 1

  puts 'Preparing test databases...'

  1.upto(workers) do |worker|
    test_env_number = worker == 1 ? '' : worker.to_s
    database_name = "tariff_test#{test_env_number}"
    env = {
      'RAILS_ENV' => 'test',
      'TEST_ENV_NUMBER' => test_env_number,
    }
    command = %w[bundle exec rails db:drop db:create db:structure:load]

    stdout, stderr, status = Open3.capture3(env, *command)

    if ENV['PARALLEL_TEST_PREPARE_VERBOSE'] == 'true'
      puts stdout
      warn stderr
    end

    unless status.success?
      puts stdout
      warn stderr
      abort "Failed to prepare #{database_name}"
    end

    puts "Prepared #{database_name}"
  end
end

if Rails.env.test?
  Rake::Task['db:structure:load'].enhance do
    Rake::Task['db:test:populate_empty_materialized_views'].invoke
  end
end
