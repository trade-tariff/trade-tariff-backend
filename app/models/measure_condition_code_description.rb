class MeasureConditionCodeDescription < Sequel::Model
  set_primary_key [:condition_code]

  plugin :oplog, primary_key: :condition_code
  plugin :static_cache, frozen: false unless Rails.env.test?
end
