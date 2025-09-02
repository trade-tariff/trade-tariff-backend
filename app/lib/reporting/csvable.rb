module Reporting
  module Csvable
    extend ActiveSupport::Concern

    def save_document(object, object_key, data)
      return if data.blank?

      File.write(File.basename(object_key), data) if Rails.env.development?

      if Rails.env.production?
        object.put(
          body: data,
          content_type: 'text/csv',
        )
      end
    end
  end
end
