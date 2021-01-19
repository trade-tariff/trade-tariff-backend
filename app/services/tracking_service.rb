class TrackingService
  TrackingServiceError = Class.new(StandardError)
  BatchTooBigError = Class.new(StandardError)
  MissingAttributesError = Class.new(StandardError)

  DEBUG_API_ENDPOINT = 'https://www.google-analytics.com/debug/collect'.freeze
  BATCH_API_ENDPOINT = 'https://www.google-analytics.com/batch'.freeze

  MAX_BATCH_SIZE = 20

  attr_reader :ga_tracking_id, :client_tracking_data

  def initialize(
    ga_tracking_id: Rails.configuration.google_analytics_tracking_id,
    client_tracking_data: {},
    debug: false
  )
    @client_tracking_data = client_tracking_data
    @ga_tracking_id = ga_tracking_id
    @debug = debug
  end

  def track_events(props:)
    raise MissingAttributesError, 'Event props must be present' unless props.present?

    return unless ga_tracking_id && client_tracking_data[:ga_cookie].present?

    send_events(props)
  rescue StandardError => e
    Rails.logger.error("Tracking service error: #{e.message}")
    raise TrackingServiceError, e.message
  end

  private

  def debug_uri
    URI.parse(DEBUG_API_ENDPOINT)
  end

  def batch_uri
    URI.parse(BATCH_API_ENDPOINT)
  end

  def send_events(props)
    raise BatchTooBigError, "Batch size cannot be over #{MAX_BATCH_SIZE}" if props.size > MAX_BATCH_SIZE

    net_http_post(props).body
  end

  def debugging_enabled?
    @debug
  end

  def client_tracking_info
    {
      cid: client_tracking_data[:ga_cookie],
      uip: client_tracking_data[:ip_address],
      ua: client_tracking_data[:user_agent]
    }
  end

  def build_payload(key, label, value)
    URI.encode_www_form(
      {
        tid: ga_tracking_id,
        t: 'event',
        v: 1,
        ec: key,
        el: label,
        ea: value
      }.merge(client_tracking_info)
    )
  end

  def build_batch_payload(props)
    props.map { |prop| build_payload(prop[:key], prop[:label], prop[:value]) }.join("\n")
  end

  def net_http_post(props)
    return ::Net::HTTP.post(batch_uri, build_batch_payload(props)) unless debugging_enabled?

    prop = props.first

    ::Net::HTTP.post(debug_uri, build_payload(prop[:key], prop[:label], prop[:value]))
  end
end
