class Serializer < SimpleDelegator
  include ActiveModel::Serializers::JSON

  self.include_root_in_json = false

  attr_reader :record

  def initialize(record)
    @record = record
    super(@record)
  end

  def to_json(opts = {})
    as_json(opts).to_json
  end
end
