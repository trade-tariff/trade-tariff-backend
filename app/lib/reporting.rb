module Reporting
  extend Reportable

  def self.get(object_key)
    if Rails.env.production?
      object(object_key).get.body.read
    else

      File.open(object_key)
    end
  end
end
