require "net/http"

# Renders a Caddyfile from the current Setting + Service rows and pushes it to
# Caddy's admin API at /load. The push is idempotent — Caddy diffs the new
# config against the running one and only reloads what changed.
#
# Triggered:
#   - On every after_commit of Setting and Service (via .publish_async).
#   - On Rails boot, by an initializer (so a Caddy restart re-syncs from DB).
#   - Manually, via the "Republish" button in the UI (.publish! / sync error).
#
# Failures are logged but never raise — a misconfigured Caddy or transient
# network blip shouldn't take down the admin UI. Use the UI's "Republish"
# button to retry.
class CaddyPublisher
  ADMIN_URL = ENV.fetch("CADDY_ADMIN_URL", "http://localhost:2019").freeze

  class << self
    # Fire-and-forget. Used from after_commit hooks so model saves don't block
    # on Caddy responding (or being reachable at all).
    def publish_async
      Thread.new { publish! rescue Rails.logger.error("[CaddyPublisher] async: #{_1.message}") }
    end

    # Synchronous push. Returns [ok?, message]. Used by the manual Republish
    # action so the UI can surface success/failure.
    def publish!
      caddyfile = render

      # Caddy's /load rejects an empty body with `EOF` from the caddyfile
      # adapter, so skip the push entirely when there's nothing to apply
      # (settings not yet configured). Caddy keeps its bootstrap config,
      # which serves nothing on 80/443 — the correct state until the user
      # finishes setup in the UI.
      if caddyfile.strip.empty?
        Rails.logger.info("[CaddyPublisher] settings not yet complete; skipping push")
        return [ true, "Settings incomplete — finish setup to start serving." ]
      end

      uri = URI.join(ADMIN_URL, "/load")

      req = Net::HTTP::Post.new(uri)
      req["Content-Type"] = "text/caddyfile"
      req.body = caddyfile

      res = Net::HTTP.start(uri.hostname, uri.port, open_timeout: 2, read_timeout: 5) do |http|
        http.request(req)
      end

      if res.is_a?(Net::HTTPSuccess)
        Rails.logger.info("[CaddyPublisher] applied config (#{Service.enabled.count} sites)")
        [ true, "Caddy reloaded with #{Service.enabled.count} site(s)." ]
      else
        Rails.logger.error("[CaddyPublisher] #{res.code}: #{res.body}")
        [ false, "Caddy rejected config (#{res.code}): #{res.body}" ]
      end
    rescue StandardError => e
      Rails.logger.error("[CaddyPublisher] #{e.class}: #{e.message}")
      [ false, "Couldn't reach Caddy at #{ADMIN_URL}: #{e.message}" ]
    end

    # Build the Caddyfile from the database. Public mostly so the UI can show
    # a "preview" of what will be sent.
    def render
      setting = Setting.instance
      sites = Service.enabled.ordered

      # If we don't yet have credentials, push an empty config — Caddy will
      # serve nothing on 80/443, which is the right state during setup.
      return "" unless setting.complete?

      lines = []
      lines << "{"
      lines << "    admin localhost:2019"
      lines << "    email #{setting.acme_email}"
      lines << "}"
      lines << ""
      lines << "(cloudflare_tls) {"
      lines << "    tls {"
      # Token is inlined here — Caddy holds it in memory + /config volume.
      # That's the same trust boundary as the SQLite DB it came from.
      lines << "        dns cloudflare #{setting.cloudflare_token}"
      lines << "    }"
      lines << "}"

      sites.each do |s|
        lines << ""
        lines << "# #{s.name}"
        lines << "#{s.hostname} {"
        lines << "    import cloudflare_tls"
        lines << "    reverse_proxy #{s.upstream}"
        lines << "}"
      end

      lines.join("\n") + "\n"
    end
  end
end
