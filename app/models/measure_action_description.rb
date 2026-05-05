class MeasureActionDescription < Sequel::Model
  plugin :oplog, primary_key: :action_code
  plugin :static_cache, frozen: false unless Rails.env.test?

  set_primary_key [:action_code]
end
