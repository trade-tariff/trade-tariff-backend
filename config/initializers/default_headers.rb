Rails.application.config.action_dispatch.default_headers.merge!(
  'X-Frame-Options' => 'DENY',
  'Content-Security-Policy' => "default-src 'none'; frame-ancestors 'none'",
)
