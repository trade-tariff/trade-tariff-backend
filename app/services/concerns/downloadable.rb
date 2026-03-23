module Downloadable
  CONTENT_TYPE_XLSX = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'.freeze

  module ClassMethods
    def export_payload(args)
      raise NotImplementedError, "#{self} must implement .export_payload(args)"
    end
  end

  def create_payload
    raise NotImplementedError, "#{self.class.name} must implement #create_payload"
  end
end
