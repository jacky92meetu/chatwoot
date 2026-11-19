require 'resolv'
require 'ipaddr'
require 'shellwords'

# Rejects spoke targets that could reach internal services (SSRF). The same rules run in the Hub Router at call time.
class N8n::SpokeUrlGuard
  BLOCKED_SUFFIXES = %w[local localhost internal lan home corp docker].freeze
  BLOCKED_RANGES = %w[
    0.0.0.0/8 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 169.254.0.0/16 172.16.0.0/12 192.0.0.0/24
    192.0.2.0/24 192.168.0.0/16 198.18.0.0/15 198.51.100.0/24 203.0.113.0/24 224.0.0.0/4 240.0.0.0/4
    ::1/128 fc00::/7 fe80::/10
  ].map { |range| IPAddr.new(range) }.freeze
  VALUE_FLAGS = %w[-X --request -H --header -d --data --data-raw --data-binary].freeze

  def self.allowed?(url, account_id:, use_allowlist: true)
    new(account_id, use_allowlist: use_allowlist).allowed?(url)
  end

  # Returns the error message for an api_template, or nil when its target is safe.
  def self.template_error(template, account_id:)
    guard = new(account_id)
    target = guard.template_target(template)
    return nil if target.nil?

    guard.allowed?(target) ? nil : 'targets a blocked address (internal, private or non-http(s) hosts are not allowed)'
  rescue ArgumentError
    'is not a valid curl command'
  end

  def initialize(account_id, use_allowlist: true)
    @account_id = account_id
    @use_allowlist = use_allowlist
  end

  def allowed?(url)
    uri = URI.parse(url.to_s.strip)
    return false unless %w[http https].include?(uri.scheme) && uri.host.present? && uri.userinfo.blank?

    host = uri.host.downcase.delete_suffix('.')
    return true if @use_allowlist && allowed_hosts.include?(host)
    return false if literal_or_internal_name?(host)

    public_addresses?(host)
  rescue URI::InvalidURIError
    false
  end

  # Builds the request URL the same way the Hub Router does, replacing unknown placeholders with a dummy value.
  def template_target(template)
    tokens = Shellwords.split(template.to_s)
    target = nil
    skip_next = false
    tokens.drop(1).each do |token|
      if skip_next
        skip_next = false
      elsif VALUE_FLAGS.include?(token)
        skip_next = true
      elsif !token.start_with?('-')
        target = token
      end
    end
    target && substitute(target)
  end

  private

  def substitute(target)
    vars = global_vars
    target.gsub(/\{([A-Za-z0-9_]+)\}/) { vars[Regexp.last_match(1)].is_a?(String) ? vars[Regexp.last_match(1)] : 'x' }
  end

  def global_vars
    @global_vars ||= N8nHubGlobalVar.where(account_id: @account_id, is_active: true).pluck(:name, :value).to_h
  end

  def allowed_hosts
    @allowed_hosts ||= Array(N8nTenantRoute.find_by(account_id: @account_id)&.spoke_allowed_hosts).map(&:downcase)
  end

  def literal_or_internal_name?(host)
    host.exclude?('.') || host.include?(':') || host.match?(/\A[\dx.]+\z/i) ||
      host.end_with?(*BLOCKED_SUFFIXES.map { |suffix| ".#{suffix}" })
  end

  def public_addresses?(host)
    addresses = Resolv.getaddresses(host)
    addresses.any? && addresses.none? { |address| BLOCKED_RANGES.any? { |range| range.include?(IPAddr.new(address)) } }
  end
end
