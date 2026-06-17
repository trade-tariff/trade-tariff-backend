module JsonapiSerializerQueryOptions
  def initialize(resource, options = {})
    query_options = Thread.current[:jsonapi_query_options]
    options = options.to_h.dup

    if query_options.present?
      options[:fields] = query_options[:fields] if query_options[:fields].present?
      options[:include] = query_options[:include] if query_options[:include_requested]
      options[:include] = sparse_fieldset_includes(options[:include], query_options[:fields])
    end

    validate_requested_includes!(options[:include]) if options[:include].present?

    super(resource, options)
  end

  private

  def validate_requested_includes!(includes)
    relationships = self.class.relationships_to_serialize || {}

    includes.each do |include_item|
      include_base = include_item.to_s.split('.', 2).first.to_sym
      next if relationships.key?(include_base)

      raise JSONAPI::Serializer::UnsupportedIncludeError.new(include_base, self.class.name)
    end
  end

  def sparse_fieldset_includes(includes, fieldsets)
    return includes if includes.blank? || fieldsets.blank?

    fields = fieldsets[self.class.record_type.to_sym]
    return includes unless fields

    Array(includes).select do |include_item|
      fields.include?(include_item.to_s.split('.', 2).first.to_sym)
    end
  end
end

FastJsonapi::ObjectSerializer.prepend(JsonapiSerializerQueryOptions)
