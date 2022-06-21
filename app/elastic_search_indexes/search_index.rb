class SearchIndex
  delegate :dataset, to: :model_class

  def initialize(server_namespace = TradeTariffBackend::SearchClient.server_namespace)
    @server_namespace = server_namespace
  end

  def name
    [@server_namespace, type.pluralize].join('-')
  end

  def name_without_namespace
    self.class.name.split('::').last
  end

  def type
    model_class.to_s.underscore
  end

  def model_class
    name_without_namespace.chomp('Index').constantize
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
