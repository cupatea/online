module DashboardHelper
  # High-quality icons from the dashboard-icons project (homarr-labs), served
  # over jsDelivr. Keyed by an app-name slug.
  ICONS_CDN = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons".freeze

  # Profiles shown in the bottom-right dock.
  def dock_profiles
    Profile.ordered
  end

  # Icon for a Caddy service tile (favicon fallback derived from its hostname).
  def tile_icon(service)
    icon_chip(icon: service.icon, host: service.hostname, label: service.name)
  end

  # Icon for a personal link tile (favicon fallback derived from the link URL).
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
  #   1. A manually set icon — image URL → <img>, anything else (emoji) → text.
  #   2. Otherwise an <img> that cascades through, on each load error:
  #        dashboard-icons SVG → dashboard-icons PNG → site favicon → (removed).
  #      When the <img> is removed the letter monogram underneath shows through.
  #      (CSP is disabled, so the inline onerror handler runs.)
  def icon_chip(icon:, host:, label:)
    icon = icon.to_s.strip

    if icon.start_with?("http://", "https://", "/")
      return image_tag(icon, class: "tile-icon", alt: "", loading: "lazy")
    elsif icon.present?
      return content_tag(:span, icon, class: "tile-icon")
    end

    monogram = content_tag(:span, label.to_s.first.to_s.upcase, class: "tile-monogram")
    sources  = icon_sources(label: label, host: host)
    return content_tag(:span, monogram, class: "tile-icon tile-icon-auto") if sources.empty?

    img = tag.img(
      src: sources.first,
      class: "tile-favicon",
      alt: "", loading: "lazy",
      data: { srcs: sources.drop(1).to_json },
      # Try the next source on error; remove (revealing the monogram) when none left.
      onerror: "var s=JSON.parse(this.dataset.srcs||'[]');if(s.length){this.src=s.shift();" \
               "this.dataset.srcs=JSON.stringify(s);}else{this.remove();}"
    )
    content_tag(:span, monogram + img, class: "tile-icon tile-icon-auto")
  end

  def icon_sources(label:, host:)
    slug = label.to_s.parameterize
    sources = []
    if slug.present?
      sources << "#{ICONS_CDN}/svg/#{slug}.svg"
      sources << "#{ICONS_CDN}/png/#{slug}.png"
    end
    sources << "https://#{host}/favicon.ico" if host.present?
    sources
  end
end
