class MeasureActionDescription < Sequel::Model
  set_primary_key [:action_code]

  plugin :oplog, primary_key: :action_code
  plugin :static_cache, frozen: false unless Rails.env.test?
end
