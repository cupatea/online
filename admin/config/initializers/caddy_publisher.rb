# Re-sync Caddy from the database when the admin app boots. This makes sure
# a Caddy restart (or a fresh deployment) picks up the current config without
# requiring the user to press "Republish".
#
# Skipped during rake tasks like `assets:precompile` and during DB-less boots
# (initial container start before migrations have run).

Rails.application.config.after_initialize do
  next if defined?(Rails::Console)
  next unless ActiveRecord::Base.connection.data_source_exists?("settings")

  CaddyPublisher.publish_async
rescue StandardError => e
  Rails.logger.warn("[CaddyPublisher] boot sync skipped: #{e.message}")
end
