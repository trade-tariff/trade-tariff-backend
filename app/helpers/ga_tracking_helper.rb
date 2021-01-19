module GaTrackingHelper
  def track_event(event_key, event_value, scope = 'events')
    event_label = I18n.t(event_key, scope: scope)

    track_events(
      [
        {
          key: event_key,
          label: event_label,
          value: event_value
        }
      ]
    )
  end

  def track_events(props = [])
    TrackingService.new(client_tracking_data: client_tracking_data).track_events(props: props)
  rescue TrackingService::TrackingServiceError
    nil
  end

  private

  def client_tracking_data
    {
      ga_cookie: cookies['_ga']&.gsub(/^(.*?\..*?\.)/, ''),
      ip_address: request.remote_ip,
      user_agent: request.env['HTTP_USER_AGENT']
    }
  end
end
