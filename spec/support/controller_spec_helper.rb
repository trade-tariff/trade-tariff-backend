module ControllerSpecHelper
  def pagination_pattern
    { pagination:
      {
        page: 1,
        per_page: Integer,
        total_count: Integer,
      } }.ignore_extra_keys!
  end

  def login_as_api_user(user = User.new)
    # rubocop:disable RSpec/VerifiedDoubles
    request.env['warden'] = double(
      'Authenticated API User',
      authenticate!: true,
      authenticated?: true,
      user:,
    )
    # rubocop:enable RSpec/VerifiedDoubles
  end
end
