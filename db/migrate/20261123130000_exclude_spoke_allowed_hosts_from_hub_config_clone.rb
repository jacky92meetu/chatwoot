class ExcludeSpokeAllowedHostsFromHubConfigClone < ActiveRecord::Migration[7.1]
  # New accounts must NOT inherit the spoke host allowlist: every tenant decides
  # which (if any) internal hosts its spoke templates may reach.
  #
  # This also restates the `rag_site` exclusion, which exists in production but was
  # missing from 20261119090000/20261119091000, so a fresh deploy clones neither
  # crawler sources nor the spoke allowlist.
  def up
    replace_clone_function(exclude_spoke_hosts: true)
  end

  def down
    replace_clone_function(exclude_spoke_hosts: false)
  end

  private

  def replace_clone_function(exclude_spoke_hosts:)
    extra = exclude_spoke_hosts ? "\n            AND NOT (config_type = 'setting' AND name = 'spokeAllowedHosts')" : ''

    execute <<~SQL.squish
      CREATE OR REPLACE FUNCTION n8n_clone_hub_configs_for_new_account() RETURNS trigger AS $$
      BEGIN
        IF NEW.id <> 1 THEN
          INSERT INTO n8n_hub_configs (
            account_id, config_type, name, value, default_value, description, is_active, created_at, updated_at
          )
          SELECT NEW.id, config_type, name, value, default_value, description, is_active, now(), now()
          FROM n8n_hub_configs
          WHERE account_id = 1
            AND config_type <> 'rag_site'#{extra}
          ON CONFLICT (account_id, config_type, name) DO NOTHING;
        END IF;
        RETURN NEW;
      END
      $$ LANGUAGE plpgsql;
    SQL
  end
end
