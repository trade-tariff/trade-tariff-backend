collection @changes

attributes :oid, :model_name, :operation, :operation_date

node(:record) do |change|
  partial "api/v1/#{change.to_partial_path}", object: change.record
end
