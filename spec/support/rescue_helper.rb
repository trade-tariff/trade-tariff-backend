# rubocop:disable Lint/SuppressedException
module RescueHelper
  def rescuing
    yield
  rescue StandardError
  end
end
# rubocop:enable Lint/SuppressedException
