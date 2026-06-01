class ApplicationController < ActionController::Base
  allow_browser versions: :modern

  before_action :block_admin_in_dashboard_mode

  # True when the request arrived on DASHBOARD_PORT. We read the LOCAL accepted-
  # socket port, NOT SERVER_PORT — Puma derives SERVER_PORT from the Host header
  # / X-Forwarded-Proto, which is 443 behind Caddy and can't tell the admin port
  # from the dashboard port. puma.socket is set on every request; .to_io makes
  # it work for plain and TLS sockets alike. Fails closed (admin-only) when
  # DASHBOARD_PORT is unset, so a misconfigured deploy never exposes admin.
  def self.dashboard_request?(request)
    port = ENV["DASHBOARD_PORT"]
    return false if port.nil? || port.strip.empty?

    request.env["puma.socket"]&.to_io&.local_address&.ip_port == port.to_i
  end

  private

  def dashboard_mode? = self.class.dashboard_request?(request)
  helper_method :dashboard_mode?

  # The access boundary: on the dashboard port only DashboardController may run;
  # every admin controller (Services, Settings) bounces to the launcher, so
  # admin actions never execute there. No-op on the admin port. /up is
  # unaffected — Rails::HealthController < ActionController::Base, not this.
  def block_admin_in_dashboard_mode
    return unless dashboard_mode?
    return if instance_of?(DashboardController)

    redirect_to root_path
  end
end
