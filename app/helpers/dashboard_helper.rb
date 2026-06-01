module DashboardHelper
  # Renders a tile's icon. Precedence:
  #   1. A manually set icon — an image URL renders as <img>, anything else
  #      (typically an emoji) renders as text.
  #   2. Otherwise, the site's favicon layered over a letter monogram: if the
  #      favicon loads it covers the monogram; if it 404s, `onerror` removes the
  #      <img> and the monogram shows through. (CSP is disabled, so the inline
  #      handler runs.)
  def tile_icon(service)
    icon = service.icon.to_s.strip

    if icon.start_with?("http://", "https://", "/")
      image_tag(icon, class: "tile-icon", alt: "", loading: "lazy")
    elsif icon.present?
      content_tag(:span, icon, class: "tile-icon")
    else
      auto_tile_icon(service)
    end
  end

  private

  def auto_tile_icon(service)
    monogram = content_tag(:span, service.name.to_s.first.to_s.upcase, class: "tile-monogram")
    favicon  = image_tag("https://#{service.hostname}/favicon.ico",
                         class: "tile-favicon", alt: "", loading: "lazy",
                         onerror: "this.remove()")
    content_tag(:span, monogram + favicon, class: "tile-icon tile-icon-auto")
  end
end
