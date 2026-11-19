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
  validate :url_value_is_public, if: :will_save_change_to_value?

  private

  def url_value_is_public
    return unless value.is_a?(String) && (value.match?(%r{\Ahttps?://}i) || name.to_s.match?(/URL|HOST|ENDPOINT/i))
    return if value.blank? || N8n::SpokeUrlGuard.allowed?(value, account_id: account_id)

    errors.add(:value, 'targets a blocked address (internal, private or non-http(s) hosts are not allowed)')
  end

  def value_is_not_null
    errors.add(:value, :blank) if value.nil?
  end
end
