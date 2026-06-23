class ApplicationController < ActionController::API
  include JsonapiQueryOptions

  MAX_LOGGED_REQUEST_ID_LENGTH = 100

  include ActionController::Helpers
  include ::ActionController::MimeResponds
  # SequelRails incorrectly includes this into ActionController::Base but our
  # ApplicationController derives from ActionController::API
  include ::SequelRails::Railties::ControllerRuntime

  respond_to :json

  before_action :set_trade_tariff_request_id
  before_action :maintenance_mode_if_active
  around_action :configure_time_machine
  around_action :apply_jsonapi_query_options
  after_action  :check_query_count, if: -> { TradeTariffBackend.check_query_count? }
  after_action  :set_api_docs_link_header

  def nothing
    head :ok
  end

  protected

  def jsonapi_serializer_options(default_include: nil, **options)
    options = options.dup
    options[:include] = jsonapi_include_option(default_include)

    fields = jsonapi_sparse_fieldsets
    options[:fields] = fields if fields.present?

    options.compact
  end

  def jsonapi_options_cache_suffix(default_include: nil)
    return unless jsonapi_options_requested?

    Digest::MD5.hexdigest(
      jsonapi_serializer_options(default_include:).slice(:fields, :include).to_json,
    )
  end

  def jsonapi_options_requested?
    params.key?(:include) || params.key?(:fields)
  end

  def append_info_to_payload(payload)
    super
    payload[:request_id] = logged_request_id
    payload[:user_agent] = request.headers['HTTP_X_ORIGINAL_USER_AGENT'].presence || request.env['HTTP_USER_AGENT']
    payload[:client_id] = request.headers['HTTP_X_CLIENT_ID']
  end

  private

  def actual_date(default = Time.zone.today)
    as_of_param = params[:as_of].to_s

    # Validate the format of the date using regex
    unless as_of_param.match?(/\A\d{4}-\d{2}-\d{2}\z/)
      return default
    end

    date = Date.iso8601(as_of_param)

    # Ensure the date is within a supported range
    if date < Date.new(1, 1, 1) || date > 20.years.from_now
      default
    else
      date
    end
  rescue ArgumentError
    default
  end

  helper_method :actual_date

  def configure_time_machine(&block)
    TimeMachine.at(actual_date, &block)
  end

  def check_query_count
    QueryCountChecker.new(TradeTariffBackend.excess_query_threshold).check
  end

  def maintenance_mode_if_active
    MaintenanceMode.check! params[:maintenance_bypass]
  end

  def apply_jsonapi_query_options
    Thread.current[:jsonapi_query_options] = parsed_jsonapi_query_options if v2_api_controller?

    yield
  ensure
    Thread.current[:jsonapi_query_options] = nil if v2_api_controller?
  end

  def parsed_jsonapi_query_options
    {
      include_requested: params.key?(:include),
      include: jsonapi_include_option(nil),
      fields: jsonapi_sparse_fieldsets,
    }
  end

  def jsonapi_include_option(default_include)
    return default_include unless params.key?(:include)

    params[:include].to_s.split(',').map(&:strip).reject(&:blank?)
  end

  def jsonapi_sparse_fieldsets
    fieldsets = params[:fields]
    return {} if fieldsets.blank?

    fieldsets.to_unsafe_h.each_with_object({}) do |(type, fields), parsed|
      parsed[type.to_sym] = fields.to_s.split(',').map(&:strip).reject(&:blank?).map(&:to_sym)
    end
  end

  def v2_api_controller?
    self.class.name.start_with?('Api::V2::')
  end

  def set_trade_tariff_request_id
    TradeTariffRequest.request_id = params[:request_id].presence || request.request_id
  end

  def set_api_docs_link_header
    response.set_header('Link', '<https://api-docs.trade-tariff.service.gov.uk/llms.txt>; rel="describedby"')
  end

  def logged_request_id
    (TradeTariffRequest.request_id.presence || request.request_id).to_s.first(MAX_LOGGED_REQUEST_ID_LENGTH)
  end
end
