# frozen_string_literal: true

require 'erb'
require 'yaml'

# rubocop:disable RSpec/DescribeClass
RSpec.describe 'Database configuration' do
  subject(:production_config) do
    YAML.safe_load(
      ERB.new(File.read('config/database.yml')).result,
      aliases: true,
    ).fetch('production')
  end

  let(:writer_url) { 'postgres://tariff:secret@writer.example.test/tariff' }
  let(:reader_url) { 'postgres://tariff:secret@reader.example.test/tariff' }

  before do
    stub_const(
      'ENV',
      ENV.to_hash.merge(
        'DATABASE_URL' => writer_url,
        'READER_DATABASE_URL' => reader_url,
      ),
    )
  end

  it 'passes the reader connection string to Sequel as a conn_str' do
    reader_config = production_config.fetch('servers').fetch('reader')

    expect(reader_config).to include('conn_str' => reader_url)
    expect(reader_config).not_to have_key('url')
  end

  it 'does not configure a read_only server that Sequel would use by default for selects' do
    expect(production_config.fetch('servers')).not_to have_key('read_only')
  end

  it 'uses the writer for plain model reads unless reader routing is explicit' do
    db = Sequel.connect(
      Sequel::Model.db.opts.slice(
        :adapter,
        :host,
        :port,
        :database,
        :user,
        :password,
        :search_path,
      ).compact.merge(
        connect_sqls: ["SET application_name = 'writer'"],
        servers: {
          reader: {
            connect_sqls: ["SET application_name = 'reader'"],
          },
        },
      ),
    )
    db.extension :server_block

    expect(application_name_for(db)).to eq('writer')

    db.with_server(:reader) do
      expect(application_name_for(db)).to eq('reader')
    end
  ensure
    if db
      db.disconnect
      Sequel::DATABASES.delete(db)
    end
  end

  def application_name_for(db)
    db.fetch("SELECT current_setting('application_name') AS application_name")
      .first
      .fetch(:application_name)
  end
end
# rubocop:enable RSpec/DescribeClass
