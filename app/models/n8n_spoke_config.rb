class N8nSpokeConfig < ApplicationRecord
  self.table_name = 'n8n_spoke_configs'

  belongs_to :account

  validates :name, presence: true, length: { maximum: 100 }, uniqueness: { scope: :account_id }
  validates :api_template, presence: true
  validates :is_active, inclusion: { in: [true, false] }
  validate :parameters_is_object

  private

  def parameters_is_object
    errors.add(:parameters, 'must be a JSON object') unless parameters.is_a?(Hash)
  end
end
