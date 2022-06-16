class SearchIndex
  delegate :dataset, to: :model_class

  def initialize(server_namespace)
    @server_namespace = server_namespace
  end

  def name
    [@server_namespace, type.pluralize].join('-')
  end

  def type
    model_class.to_s.underscore
  end

  def model_class
    self.class.name.split('::').last.chomp('Index').constantize
  end

  def serializer
    self.class.name.gsub(/Index\z/, 'Serializer').constantize
  end

  def serialize_record(record)
    serializer.new(record).as_json
  end

  def goods_nomenclature?
    false
  end
end
