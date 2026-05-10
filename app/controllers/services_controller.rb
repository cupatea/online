class ServicesController < ApplicationController
  before_action :load_service, only: [ :edit, :update, :destroy ]

  def index
    @services = Service.ordered
    @setting  = Setting.instance
  end

  def new
    @service = Service.new(upstream_host: "localhost", enabled: true)
  end

  def create
    @service = Service.new(service_params)
    if @service.save
      redirect_with_publish(root_path, "Added #{@service.hostname}.")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @service.update(service_params)
      redirect_with_publish(root_path, "Updated #{@service.hostname}.")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    hostname = @service.hostname
    @service.destroy
    redirect_with_publish(root_path, "Removed #{hostname}.")
  end

  def republish
    ok, message = CaddyPublisher.publish!
    flash[ok ? :notice : :alert] = message
    redirect_to root_path
  end

  private

  def load_service
    @service = Service.find(params[:id])
  end

  def service_params
    params.require(:service).permit(:name, :hostname, :upstream_host, :upstream_port, :enabled)
  end

  # Push to Caddy synchronously so any failure (Caddy down, bad config) shows
  # up next to the success message instead of being silently logged.
  def redirect_with_publish(path, success_message)
    ok, caddy_message = CaddyPublisher.publish!
    if ok
      redirect_to path, notice: "#{success_message} #{caddy_message}"
    else
      redirect_to path, alert: "#{success_message} (Caddy not updated: #{caddy_message})"
    end
  end
end
