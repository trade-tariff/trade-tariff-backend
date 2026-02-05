# Helper for suppressing stdout during tests (e.g., rake task output)
module OutputHelpers
  def suppress_output
    original_stdout = $stdout
    $stdout = StringIO.new
    yield
  ensure
    $stdout = original_stdout
  end
end

RSpec.configure do |config|
  config.include OutputHelpers
end
