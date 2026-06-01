module DashboardHelper
  # Profiles shown in the bottom-right dock.
  def dock_profiles
    Profile.ordered
  end

  # Icon for a Caddy service tile (favicon derived from its hostname).
  def tile_icon(service)
    icon_chip(icon: service.icon, host: service.hostname, label: service.name)
  end

  # Icon for a personal link tile (favicon derived from the link's URL host).
  def link_icon(link)
    host = begin
      URI.parse(link.url.to_s).host
    rescue URI::InvalidURIError
      nil
    end
    icon_chip(icon: link.icon, host: host, label: link.title)
  end

  private

  # Renders a tile icon chip. Precedence:
  #   1. A manually set icon — an image URL renders as <img>, anything else
  #      (typically an emoji) renders as text.
  #   2. Otherwise the host's favicon layered over a letter monogram: if the
  #      favicon loads it covers the monogram; if it 404s, `onerror` removes the
  #      <img> and the monogram shows through. (CSP is disabled, so it runs.)
  def icon_chip(icon:, host:, label:)
    icon = icon.to_s.strip

    if icon.start_with?("http://", "https://", "/")
      image_tag(icon, class: "tile-icon", alt: "", loading: "lazy")
    elsif icon.present?
      content_tag(:span, icon, class: "tile-icon")
    else
      monogram = content_tag(:span, label.to_s.first.to_s.upcase, class: "tile-monogram")
      favicon  = host.present? ? image_tag("https://#{host}/favicon.ico",
                                            class: "tile-favicon", alt: "", loading: "lazy",
                                            onerror: "this.remove()") : "".html_safe
      content_tag(:span, monogram + favicon, class: "tile-icon tile-icon-auto")
    end
  end
end
