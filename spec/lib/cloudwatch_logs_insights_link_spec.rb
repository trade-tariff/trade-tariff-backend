RSpec.describe CloudwatchLogsInsightsLink do
  describe '.for_job' do
    subject(:url) do
      described_class.for_job(
        jid: '93ce163da1a9f7052e55d7c6',
        from: Time.utc(2026, 9, 21, 10, 0, 0),
        to: Time.utc(2026, 9, 21, 10, 30, 0),
      )
    end

    before do
      allow(TradeTariffBackend).to receive_messages(
        aws_region: 'eu-west-2',
        environment: ActiveSupport::StringInquirer.new('production'),
      )
    end

    it 'opens Logs Insights in the configured region' do
      expect(url).to start_with(
        'https://eu-west-2.console.aws.amazon.com/cloudwatch/home?region=eu-west-2#logsV2:logs-insights$3FqueryDetail$3D~(',
      )
    end

    it 'queries the platform log group for the environment' do
      expect(url).to include("~source~(~'platform-logs-production)")
    end

    it 'uses an absolute UTC time window' do
      expect(url).to include(
        "~(end~'2026-09-21T10*3A30*3A00.000Z~start~'2026-09-21T10*3A00*3A00.000Z~timeType~'ABSOLUTE~tz~'UTC~",
      )
    end

    it 'filters the log lines by job ID' do
      expected_query = 'fields @timestamp, @message | filter @message like "93ce163da1a9f7052e55d7c6" | sort @timestamp asc'

      expect(url).to include("~editorString~'#{ERB::Util.url_encode(expected_query).tr('%', '*')}~")
    end

    it 'escapes characters that the console uses as delimiters' do
      url = described_class.for_job(jid: "a~b'c(d)e", from: Time.utc(2026, 1, 1), to: Time.utc(2026, 1, 1))
      editor_string = url[/editorString~'([^~]*)~source/, 1]

      expect(editor_string).to include('a*7Eb*27c*28d*29e')
    end

    it 'returns a URL without spaces or percent signs' do
      expect(url).not_to match(/[ %]/)
    end
  end
end
