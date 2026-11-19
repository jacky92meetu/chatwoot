class UpdateN8nHubConfigCloneTimestamps < ActiveRecord::Migration[7.1]
  def up
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
          ON CONFLICT (account_id, config_type, name) DO NOTHING;
        END IF;
        RETURN NEW;
      END
      $$ LANGUAGE plpgsql;
    SQL
  end

  def down
    execute <<~SQL.squish
      CREATE OR REPLACE FUNCTION n8n_clone_hub_configs_for_new_account() RETURNS trigger AS $$
      BEGIN
        IF NEW.id <> 1 THEN
          INSERT INTO n8n_hub_configs (account_id, config_type, name, value, default_value, description, is_active)
          SELECT NEW.id, config_type, name, value, default_value, description, is_active
          FROM n8n_hub_configs
          WHERE account_id = 1
          ON CONFLICT (account_id, config_type, name) DO NOTHING;
        END IF;
        RETURN NEW;
      END
      $$ LANGUAGE plpgsql;
    SQL
  end
end
