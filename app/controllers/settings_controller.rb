class SettingsController < ApplicationController
  before_action :load_setting

  def show
  end

  def update
    unless cloudflare_token_change_authorized?
      @setting.errors.add(:cloudflare_token, "requires your current admin password")
      return render :show, status: :unprocessable_entity
    end

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

  def cloudflare_token_change_authorized?
    submitted_token = setting_params[:cloudflare_token].to_s
    return true if ActiveSupport::SecurityUtils.secure_compare(submitted_token, @setting.cloudflare_token.to_s)

    @setting.authenticate_admin_password(params.dig(:setting, :current_password))
  end
end
