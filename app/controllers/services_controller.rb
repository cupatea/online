class ServicesController < ApplicationController
  before_action :load_service, only: [ :edit, :update, :destroy ]
  before_action :load_form_options, only: [ :new, :create, :edit, :update ]

  def index
    @services = Service.ordered
    @setting  = Setting.instance
  end

  def new
    @service = Service.new(
      enabled:       true,
      upstream_host: @default_upstream_host,
      base_domain:   @default_base_domain,
      upstream_port: @detected_ports.first
    )
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
    @service.assign_host_parts(@base_domain_options)
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

  # Datalist suggestions + sensible defaults for the form: configured presets
  # first (their top entry is the default), then values learned from existing
  # services. Ports come from HostPorts, minus ones already mapped.
  def load_form_options
    setting = Setting.instance

    @upstream_host_options = (setting.upstream_host_list + Service.distinct_upstream_hosts).uniq
    @base_domain_options   = (setting.base_domain_list + Service.derived_base_domains).uniq
    @default_upstream_host = @upstream_host_options.first.presence || "localhost"
    @default_base_domain   = @base_domain_options.first

    mapped          = Service.where.not(id: @service&.id).pluck(:upstream_port)
    @detected_ports = HostPorts.detected(exclude: mapped)
    @port_options   = HostPorts.suggestions(exclude: mapped)
  end

  def service_params
    params.require(:service)
          .permit(:name, :subdomain, :base_domain, :upstream_host, :upstream_port, :enabled, :icon, :description)
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
