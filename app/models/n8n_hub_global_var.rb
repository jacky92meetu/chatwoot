class N8nHubGlobalVar < ApplicationRecord
  self.table_name = 'n8n_hub_global_vars'

  belongs_to :account

  validates :name,
            presence: true,
            length: { maximum: 100 },
            format: { with: /\A[A-Za-z_][A-Za-z0-9_]*\z/ },
            uniqueness: { scope: :account_id }
  validates :is_secret, :is_active, inclusion: { in: [true, false] }
  validate :value_is_not_null

  private

  def value_is_not_null
    errors.add(:value, :blank) if value.nil?
  end
end
