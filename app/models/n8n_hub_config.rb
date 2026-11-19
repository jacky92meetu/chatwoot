class N8nHubConfig < ApplicationRecord
  self.table_name = 'n8n_hub_configs'

  CONFIG_TYPES = %w[intent spoke flowise rag_site model message instruction report rag_engine setting].freeze

  belongs_to :account

  validates :config_type, inclusion: { in: CONFIG_TYPES }
  validates :name, presence: true, length: { maximum: 100 }, uniqueness: { scope: %i[account_id config_type] }
  validates :is_active, inclusion: { in: [true, false] }
  validate :default_value_is_object
  validate :value_is_object

  private

  def default_value_is_object
    errors.add(:default_value, 'must be a JSON object') unless default_value.is_a?(Hash)
  end

  def value_is_object
    errors.add(:value, 'must be a JSON object') unless value.nil? || value.is_a?(Hash)
  end
end
