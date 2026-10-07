# Builds an AWS console URL that opens CloudWatch Logs Insights on the
# platform log group, with a query for every log line that mentions a job ID.
#
# The console reads its query from the URL fragment in its own format:
# values are percent-encoded, then each '%' becomes '*', and '~' separates
# the keys and values. The fragment's '?' and '=' are written as '$3F' and '$3D'.
class CloudwatchLogsInsightsLink
  def self.for_job(jid:, from:, to:)
    region = TradeTariffBackend.aws_region
    log_group_name = "platform-logs-#{TradeTariffBackend.environment}"
    query = "fields @timestamp, @message | filter @message like #{jid.to_s.to_json} | sort @timestamp asc"

    query_detail = "~(end~'#{console_escape(to.utc.iso8601(3))}" \
      "~start~'#{console_escape(from.utc.iso8601(3))}" \
      "~timeType~'ABSOLUTE~tz~'UTC" \
      "~editorString~'#{console_escape(query)}" \
      "~source~(~'#{console_escape(log_group_name)}))"

    "https://#{region}.console.aws.amazon.com/cloudwatch/home?region=#{region}" \
      "#logsV2:logs-insights$3FqueryDetail$3D#{query_detail}"
  end

  # ERB::Util.url_encode leaves '~' as it is, but the console uses '~' as a
  # separator, so we encode it too.
  def self.console_escape(value)
    ERB::Util.url_encode(value).gsub('~', '%7E').tr('%', '*')
  end
  private_class_method :console_escape
end
