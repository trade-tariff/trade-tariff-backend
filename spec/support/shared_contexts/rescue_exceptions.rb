RSpec.shared_context 'with rescued exceptions' do
  # In the tests, RSpec reuses an instance of Rack::Test::Request across all
  # specs, this reads these config values in instantiation time and is then used
  # for the entire duration of the test suite run
  #
  # This shared context changes those values for the duration of a single spec
  # to allow testing exceptions are rescued appropriately
  around do |example|
    orig_show_exceptions = Rails.application.env_config['action_dispatch.show_exceptions']
    orig_detailed_exceptions = Rails.application.env_config['action_dispatch.show_detailed_exceptions']

    Rails.application.env_config['action_dispatch.show_exceptions'] = true
    Rails.application.env_config['action_dispatch.show_detailed_exceptions'] = false

    example.run

    Rails.application.env_config['action_dispatch.show_detailed_exceptions'] = orig_detailed_exceptions
    Rails.application.env_config['action_dispatch.show_exceptions'] = orig_show_exceptions
  end
end
