module Downloadable
  CONTENT_TYPE_XLSX = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'.freeze

  def download_payload
    raise NotImplementedError, "#{self.class.name} must implement #download_payload"
  end
end
