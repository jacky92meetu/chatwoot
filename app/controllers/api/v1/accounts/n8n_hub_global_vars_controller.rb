class Api::V1::Accounts::N8nHubGlobalVarsController < Api::V1::Accounts::N8nSettingsController
  private

  def settings_model
    N8nHubGlobalVar
  end

  def resource_param
    :n8n_hub_global_var
  end

  def serialized_attributes
    %i[id name value description is_secret is_active created_at updated_at]
  end

  def permitted_params
    permit_resource_params(
      scalar_fields: %i[name description is_secret is_active],
      json_fields: %i[value]
    )
  end
end
