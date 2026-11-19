class N8nHubConfig < ApplicationRecord
  self.table_name = 'n8n_hub_configs'

  CONFIG_TYPES = %w[intent spoke flowise rag_site model message instruction report rag_engine setting].freeze

  belongs_to :account

  validates :config_type, inclusion: { in: CONFIG_TYPES }
  validates :name, presence: true, length: { maximum: 100 }, uniqueness: { scope: %i[account_id config_type] }
  validates :is_active, inclusion: { in: [true, false] }
  validate :default_value_is_object
  validate :value_is_object
  validate :rag_site_url_is_public

  private

  def rag_site_url_is_public
    return unless config_type == 'rag_site'

    [default_value, value].each do |config|
      next unless config.is_a?(Hash)

      url = config['url'].to_s
      unless N8n::SpokeUrlGuard.allowed?(url, account_id: account_id, use_allowlist: false)
        errors.add(:base, 'Source URL must be a public http(s) address')
        break
      end
    end
  end

  def default_value_is_object
    errors.add(:default_value, 'must be a JSON object') unless default_value.is_a?(Hash)
  end

  def value_is_object
    errors.add(:value, 'must be a JSON object') unless value.nil? || value.is_a?(Hash)
  end
end
