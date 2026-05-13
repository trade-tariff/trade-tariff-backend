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

  it 'passes the read-only connection string to Sequel as a conn_str' do
    read_only_config = production_config.fetch('servers').fetch('read_only')

    expect(read_only_config).to include('conn_str' => reader_url)
    expect(read_only_config).not_to have_key('url')
  end
end
# rubocop:enable RSpec/DescribeClass
