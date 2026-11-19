class CreateN8nSettingsManagement < ActiveRecord::Migration[7.1]
  HUB_CONFIG_TYPES = %w[intent spoke flowise rag_site model message instruction report rag_engine setting].freeze

  def up
    create_hub_config_type
    create_hub_configs
    create_hub_global_vars
    create_spoke_configs
    add_constraints
    add_updated_at_triggers
    add_account_clone_trigger
  end

  def down
    raise ActiveRecord::IrreversibleMigration, 'These tables may contain n8n configuration managed outside Rails'
  end

  private

  def create_hub_config_type
    values = HUB_CONFIG_TYPES.map { |value| connection.quote(value) }.join(', ')
    execute <<~SQL.squish
      DO $$
      BEGIN
        CREATE TYPE hub_config_type AS ENUM (#{values});
      EXCEPTION
        WHEN duplicate_object THEN NULL;
      END
      $$;
    SQL
  end

  def create_hub_configs
    return if table_exists?(:n8n_hub_configs)

    create_table :n8n_hub_configs, id: :uuid, default: -> { 'gen_random_uuid()' } do |table|
      table.bigint :account_id, null: false
      table.column :config_type, :hub_config_type, null: false
      table.string :name, limit: 100, null: false
      table.jsonb :value
      table.jsonb :default_value, null: false
      table.text :description
      table.boolean :is_active, null: false, default: true
      table.timestamps null: false, default: -> { 'CURRENT_TIMESTAMP' }
    end
  end

  def create_hub_global_vars
    return if table_exists?(:n8n_hub_global_vars)

    create_table :n8n_hub_global_vars, id: :uuid, default: -> { 'gen_random_uuid()' } do |table|
      table.bigint :account_id, null: false
      table.string :name, limit: 100, null: false
      table.jsonb :value, null: false
      table.text :description
      table.boolean :is_secret, null: false, default: false
      table.boolean :is_active, null: false, default: true
      table.timestamps null: false, default: -> { 'CURRENT_TIMESTAMP' }
    end
  end

  def create_spoke_configs
    return if table_exists?(:n8n_spoke_configs)

    create_table :n8n_spoke_configs, id: false do |table|
      # rubocop:disable Rails/DangerousColumnNames
      table.string :id, limit: 36, null: false, default: -> { 'gen_random_uuid()' }, primary_key: true
      # rubocop:enable Rails/DangerousColumnNames
      table.bigint :account_id, null: false
      table.string :name, limit: 100, null: false
      table.text :description
      table.jsonb :parameters, null: false, default: {}
      table.text :api_template, null: false
      table.jsonb :response_template
      table.text :output_template
      table.text :ai_data_request_instruction
      table.text :ai_output_instruction
      table.boolean :is_active, null: false, default: true
      table.timestamps null: false, default: -> { 'CURRENT_TIMESTAMP' }
    end
  end

  def add_constraints
    add_foreign_key_unless_present(:n8n_hub_configs)
    add_foreign_key_unless_present(:n8n_hub_global_vars)
    add_foreign_key_unless_present(:n8n_spoke_configs)

    add_unique_indexes
    change_column_null :n8n_spoke_configs, :is_active, false, true
    add_check_constraints
  end

  def add_unique_indexes
    add_unique_index_unless_present(
      :n8n_hub_configs,
      %i[account_id config_type name],
      'n8n_hub_configs_account_type_name_key'
    )
    add_unique_index_unless_present(
      :n8n_hub_global_vars,
      %i[account_id name],
      'n8n_hub_global_vars_account_name_key'
    )
    add_unique_index_unless_present(
      :n8n_spoke_configs,
      %i[account_id name],
      'n8n_spoke_configs_account_name_key'
    )
  end

  def add_check_constraints
    add_check_constraint :n8n_hub_configs, "btrim(name) <> ''",
                         name: 'hub_configs_name_not_blank', if_not_exists: true
    add_check_constraint :n8n_hub_configs, "jsonb_typeof(default_value) = 'object'",
                         name: 'hub_configs_default_value_is_object', if_not_exists: true
    add_check_constraint :n8n_hub_configs, "value IS NULL OR jsonb_typeof(value) = 'object'",
                         name: 'hub_configs_value_is_object', if_not_exists: true
    add_check_constraint :n8n_hub_global_vars, "name ~ '^[A-Za-z_][A-Za-z0-9_]*$'",
                         name: 'hub_global_vars_name_format', if_not_exists: true
    add_check_constraint :n8n_hub_global_vars, "jsonb_typeof(value) IS DISTINCT FROM 'null'",
                         name: 'hub_global_vars_value_not_null', if_not_exists: true
  end

  def add_foreign_key_unless_present(table)
    return if foreign_key_exists?(table, :accounts, column: :account_id)

    add_foreign_key table, :accounts, column: :account_id, on_delete: :cascade
  end

  def add_unique_index_unless_present(table, columns, name)
    return if index_exists?(table, columns, unique: true)

    add_index table, columns, unique: true, name: name
  end

  def add_updated_at_triggers
    execute <<~SQL.squish
      CREATE OR REPLACE FUNCTION set_hub_configs_updated_at() RETURNS trigger AS $$
      BEGIN
        NEW.updated_at = now();
        RETURN NEW;
      END
      $$ LANGUAGE plpgsql;

      DROP TRIGGER IF EXISTS set_hub_configs_updated_at ON n8n_hub_configs;
      CREATE TRIGGER set_hub_configs_updated_at
        BEFORE UPDATE ON n8n_hub_configs
        FOR EACH ROW EXECUTE FUNCTION set_hub_configs_updated_at();

      DROP TRIGGER IF EXISTS set_hub_global_vars_updated_at ON n8n_hub_global_vars;
      CREATE TRIGGER set_hub_global_vars_updated_at
        BEFORE UPDATE ON n8n_hub_global_vars
        FOR EACH ROW EXECUTE FUNCTION set_hub_configs_updated_at();
    SQL
  end

  def add_account_clone_trigger
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

      DROP TRIGGER IF EXISTS n8n_clone_hub_configs_on_account_insert ON accounts;
      CREATE TRIGGER n8n_clone_hub_configs_on_account_insert
        AFTER INSERT ON accounts
        FOR EACH ROW EXECUTE FUNCTION n8n_clone_hub_configs_for_new_account();
    SQL
  end
end
