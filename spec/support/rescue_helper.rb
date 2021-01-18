module RescueHelper
  def rescuing
    yield
  rescue StandardError
  end
end
