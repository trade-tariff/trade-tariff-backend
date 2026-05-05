class MeasureConditionCodeDescription < Sequel::Model
  plugin :oplog, primary_key: :condition_code
  plugin :static_cache, frozen: false unless Rails.env.test?

  set_primary_key [:condition_code]
end
