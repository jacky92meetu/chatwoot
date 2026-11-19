class Api::V1::Accounts::N8nHubConfigsController < Api::V1::Accounts::N8nSettingsController
  private

  def settings_model
    N8nHubConfig
  end

  def resource_param
    :n8n_hub_config
  end

  def serialized_attributes
    %i[id config_type name value default_value description is_active created_at updated_at]
  end

  def permitted_params
    permit_resource_params(
      scalar_fields: %i[config_type name description is_active],
      json_fields: %i[value default_value]
    )
  end
end
