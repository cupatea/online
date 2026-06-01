class DashboardController < ApplicationController
  SECTIONS = { "general" => "General", "technical" => "Technical" }.freeze

  def index
    grouped = Service.enabled.ordered.group_by(&:category)
    # Keep SECTIONS order (general first), dropping empty groups.
    @sections = SECTIONS.filter_map do |key, label|
      services = grouped[key]
      [ label, services ] if services.present?
    end
  end
end
