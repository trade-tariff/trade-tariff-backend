# Helper for suppressing stdout/stderr during tests (e.g., rake task output)
module OutputHelpers
  def suppress_output
    original_stdout = $stdout
    original_stderr = $stderr
    $stdout = StringIO.new
    $stderr = StringIO.new
    yield
  ensure
    $stdout = original_stdout
    $stderr = original_stderr
  end
end

RSpec.configure do |config|
  config.include OutputHelpers
end
