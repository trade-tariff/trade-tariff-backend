namespace :tariff do
  desc 'Dump all national data'
  task dump_national_data: %w[environment class_eager_load] do
    tables = Sequel::Model.subclasses.select { |k| k.columns.include?(:national) }.map(&:table_name).map(&:to_s)
    tables = tables.select { |t| t.include?('_oplog') }

    # create tables
    tables.each do |table|
      Sequel::Model.db.run(
        "CREATE TABLE IF NOT EXISTS national_#{table} AS SELECT * FROM #{table} #{table}1 WHERE #{table}1.national IS TRUE;"
      )
    end

    filename = "#{Date.today}-national.sql"

    # create dump
    `pg_dump -d tariff_development --data-only -O -x -t #{ tables.map { |t| "national_#{t}" }.join(' -t ') } -f #{filename}`

    # change table names
    `sed -i '' -e 's/national_//g' #{filename}`

    # drop tables
    tables.each do |table|
      Sequel::Model.db.run(
        "DROP TABLE IF EXISTS national_#{table};"
      )
    end
  end
end
