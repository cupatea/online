# Suggests upstream ports for the service form.
#
# Detection reads the kernel's listening TCP sockets from /proc/net/tcp[6].
# When the container runs with `network_mode: host` it shares the host's network
# namespace, so this lists the *host's* listening ports — exactly the services
# you'd want to proxy. With bridge networking (or on macOS, where /proc/net/tcp
# doesn't exist) detection finds nothing and we fall back to a list of common
# app ports. Either way the field stays free-text, so manual entry always works.
class HostPorts
  # Common self-hosted app ports, offered when nothing is detected (and merged
  # in after detected ports otherwise).
  COMMON = [ 3000, 5000, 8000, 8080, 8081, 8096, 8123, 8443, 9000, 9090, 2342, 32400 ].freeze

  # Ports the admin/Caddy stack itself listens on — never useful as upstreams.
  IGNORED = [ 80, 443, 2019, 3003, 3004 ].freeze

  class << self
    # Ports detected listening on the host, most-relevant first, minus the ones
    # already mapped to a service and the stack's own ports.
    def detected(exclude: [])
      skip = (Array(exclude) + IGNORED).map(&:to_i).to_set
      listening.reject { |port| skip.include?(port) }
    end

    # Full suggestion list for the datalist: detected ports first, then common
    # ports, de-duped, minus already-mapped and stack ports.
    def suggestions(exclude: [])
      skip = (Array(exclude) + IGNORED).map(&:to_i).to_set
      (listening + COMMON).uniq.reject { |port| skip.include?(port) }
    end

    private

    def listening
      %w[/proc/net/tcp /proc/net/tcp6].flat_map { |path| ports_from(path) }.uniq.sort
    end

    # /proc/net/tcp columns: "sl local_address rem_address st ...". st == "0A"
    # is TCP_LISTEN; local_address is "HEXIP:HEXPORT".
    def ports_from(path)
      return [] unless File.readable?(path)

      File.foreach(path).drop(1).filter_map do |line|
        cols = line.split
        next unless cols[3] == "0A"

        cols[1].split(":").last.to_i(16)
      end
    rescue StandardError
      []
    end
  end
end
