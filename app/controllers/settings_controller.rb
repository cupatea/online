class SettingsController < ApplicationController
  before_action :load_setting

  def show
  end

  def update
    if @setting.update(setting_params)
      ok, caddy_message = CaddyPublisher.publish!
      if ok
        redirect_to setting_path, notice: "Settings saved. #{caddy_message}"
      else
        redirect_to setting_path, alert: "Settings saved, but Caddy not updated: #{caddy_message}"
      end
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def load_setting
    @setting = Setting.instance
  end

  def setting_params
    params.require(:setting).permit(:acme_email, :cloudflare_token, :upstream_hosts, :base_domains)
  end
end
