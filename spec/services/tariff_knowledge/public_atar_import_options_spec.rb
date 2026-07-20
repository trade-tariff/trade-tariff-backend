RSpec.describe TariffKnowledge::PublicAtarImportOptions do
  subject(:options) { described_class.call }

  around do |example|
    original_values = {}
    names = %w[ATAR_LIMIT ATAR_MAX_PAGES ATAR_REQUEST_DELAY ATAR_MAX_RETRIES]
    original_values = names.index_with { |name| [ENV.key?(name), ENV[name]] }
    names.each { |name| ENV.delete(name) }

    example.run
  ensure
    original_values.each do |name, (present, value)|
      present ? ENV[name] = value : ENV.delete(name)
    end
  end

  it 'returns the importer defaults when environment options are unset' do
    expect(options).to eq(
      limit: nil,
      max_pages: 50,
      request_delay: TariffKnowledge::PublicAtarRulingSource::DEFAULT_REQUEST_DELAY,
      max_retries: TariffKnowledge::PublicAtarRulingSource::DEFAULT_MAX_RETRIES,
    )
  end

  it 'coerces configured environment options' do
    ENV['ATAR_LIMIT'] = '12'
    ENV['ATAR_MAX_PAGES'] = '4'
    ENV['ATAR_REQUEST_DELAY'] = '0.75'
    ENV['ATAR_MAX_RETRIES'] = '2'

    expect(options).to eq(limit: 12, max_pages: 4, request_delay: 0.75, max_retries: 2)
  end

  it 'treats a blank limit as absent' do
    ENV['ATAR_LIMIT'] = ''

    expect(options[:limit]).to be_nil
  end

  it 'reports an invalid integer option as an integer' do
    ENV['ATAR_MAX_PAGES'] = 'oops'

    expect { options }.to raise_error(ArgumentError, 'ATAR_MAX_PAGES must be an integer')
  end

  it 'reports a below-minimum integer option as an integer' do
    ENV['ATAR_MAX_PAGES'] = '0'

    expect { options }.to raise_error(ArgumentError, 'ATAR_MAX_PAGES must be an integer')
  end

  it 'reports an invalid float option as numeric' do
    ENV['ATAR_REQUEST_DELAY'] = 'oops'

    expect { options }.to raise_error(ArgumentError, 'ATAR_REQUEST_DELAY must be numeric')
  end

  it 'reports a below-minimum float option as numeric' do
    ENV['ATAR_REQUEST_DELAY'] = '-0.1'

    expect { options }.to raise_error(ArgumentError, 'ATAR_REQUEST_DELAY must be numeric')
  end
end
