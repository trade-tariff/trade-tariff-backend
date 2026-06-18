module JsonapiQueryOptions
  private

  def jsonapi_query_options
    Thread.current[:jsonapi_query_options] || {}
  end

  def jsonapi_sparse_fieldsets
    jsonapi_query_options[:fields] || {}
  end

  def jsonapi_field_requested?(type, field)
    fieldsets = jsonapi_sparse_fieldsets
    return true unless fieldsets.key?(type.to_sym)

    fieldsets[type.to_sym].include?(field.to_sym)
  end

  def jsonapi_relationship_requested?(type, relationship, default_include: nil)
    jsonapi_field_requested?(type, relationship) &&
      jsonapi_relationship_included?(relationship, default_include:)
  end

  def jsonapi_relationship_included?(relationship, default_include: nil)
    includes = jsonapi_include_requested? ? jsonapi_query_options[:include] : default_include
    relationship = relationship.to_s

    Array(includes).any? do |include_path|
      include_path.to_s.split('.', 2).first == relationship
    end
  end

  def jsonapi_include_requested?
    jsonapi_query_options[:include_requested]
  end
end
