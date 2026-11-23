class DropSpokeAllowedHostsFromN8nTenantRoutes < ActiveRecord::Migration[7.1]
  # The spoke host allowlist moved to n8n_hub_configs (config_type=setting,
  # name=spokeAllowedHosts) so it can be managed from Chatwoot -> Settings -> n8n
  # -> Hub configs. N8n::SpokeUrlGuard and the Hub Router both read it from there.
  def up
    return unless column_exists?(:n8n_tenant_routes, :spoke_allowed_hosts)

    remove_column :n8n_tenant_routes, :spoke_allowed_hosts
  end

  def down
    return if column_exists?(:n8n_tenant_routes, :spoke_allowed_hosts)

    add_column :n8n_tenant_routes, :spoke_allowed_hosts, :text, array: true, null: false, default: []
  end
end
