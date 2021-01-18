class SearchIndex
  def initialize(namespace)
    @namespace = namespace
  end

  def name
    [@namespace, type.pluralize].join('-')
  end

  def type
    model.to_s.underscore
  end

  def model
    self.class.name.split('::').last.chomp('Index').constantize
  end

  def goods_nomenclature?
    false
  end
end
