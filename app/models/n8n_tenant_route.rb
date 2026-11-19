class N8nTenantRoute < ApplicationRecord
  self.table_name = 'n8n_tenant_routes'
  self.primary_key = 'account_id'

  belongs_to :account
end
