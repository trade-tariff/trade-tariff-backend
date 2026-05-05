# json-schema is loaded by test-only dependencies. Configure it when it is
# available, but do not fail application boot in environments without the gem.
begin
  require 'json-schema'
rescue LoadError
  nil
else
  JSON::Validator.use_multi_json = false
end
