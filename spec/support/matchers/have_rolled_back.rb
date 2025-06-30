RSpec::Matchers.define :have_rolled_back do |update|
  refresh_materialized_view
  match do |_actual|
    Measure.where(filename: update.filename).none? && update.reload
  rescue Sequel::NoExistingObject
    true
  end
end
