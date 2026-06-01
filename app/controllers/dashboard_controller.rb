class DashboardController < ApplicationController
  def index
    @services = Service.enabled.ordered
  end
end
