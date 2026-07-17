Rails.application.config.session_store :cookie_store,
  key: "_online_admin_session",
  expire_after: 30.minutes,
  secure: Rails.env.production?,
  httponly: true,
  same_site: :lax
