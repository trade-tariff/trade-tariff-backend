RSpec::Matchers.define :be_a_uuid do
  match do |actual|
    actual.match?(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i)
  end

  failure_message { |actual| "expected #{actual} to be a valid UUID" }
end
