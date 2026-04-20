class SearchIndex
  delegate :dataset, to: :model_class

  def initialize(server_namespace = TradeTariffBackend::SearchClient.server_namespace)
    @server_namespace = server_namespace
  end

  def name
    [@server_namespace, type.pluralize, TradeTariffBackend.service].join('-')
  end

  def name_without_namespace
    self.class.name.split('::').last
  end

  def name_with_namespace
    self.class.name
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

  def document_id(model)
    model.id
  end

  def goods_nomenclature?
    false
  end

  def eager_load
    []
  end

  def exclude_from_search_results?
    !goods_nomenclature?
  end

  def dataset_page(page_number)
    dataset.eager(eager_load).paginate(page_number, page_size).all
  end

  def total_pages
    (dataset.count / page_size.to_f).ceil
  end

  def page_size
    500
  end

  # Allows descendants to override and apply timemachine if applicable
  def apply_constraints(&_block)
    yield
  end
end
