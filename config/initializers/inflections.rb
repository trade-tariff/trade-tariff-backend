# Be sure to restart your server when you modify this file.

# Add new inflection rules using the following format. Inflections
# are locale specific, and you may define rules for as many different
# locales as you wish. All of these examples are active by default:
# ActiveSupport::Inflector.inflections(:en) do |inflect|
#   inflect.plural /^(ox)$/i, "\\1en"
#   inflect.singular /^(ox)en/i, "\\1"
#   inflect.irregular "person", "people"
#   inflect.uncountable %w( fish sheep )
# end

# These inflection rules are supported but not enabled by default:
# ActiveSupport::Inflector.inflections(:en) do |inflect|
#   inflect.acronym "RESTful"
# end

ActiveSupport::Inflector.inflections(:en) do |inflect|
  inflect.plural %r{([a-zA-Z]+[a-rt-z])s?OfOrigin}, '\1sOfOrigin'
  inflect.plural %r{([a-zA-Z]+[a-rt-z])s?_of_origin}, '\1s_of_origin'
  inflect.singular %r{([a-zA-Z]+[a-rt-z])s?OfOrigin}, '\1OfOrigin'
  inflect.singular %r{([a-zA-Z]+[a-rt-z])s?_of_origin}, '\1_of_origin'
end
