class N8nSpokeConfig < ApplicationRecord
  self.table_name = 'n8n_spoke_configs'

  belongs_to :account

  validates :name, presence: true, length: { maximum: 100 }, uniqueness: { scope: :account_id }
  validates :api_template, presence: true
  validates :is_active, inclusion: { in: [true, false] }
  validate :parameters_is_object
  validate :api_template_target_is_public, if: :will_save_change_to_api_template?

  private

  def api_template_target_is_public
    message = N8n::SpokeUrlGuard.template_error(api_template, account_id: account_id)
    errors.add(:api_template, message) if message
  end

  def parameters_is_object
    errors.add(:parameters, 'must be a JSON object') unless parameters.is_a?(Hash)
  end
end
