class Api::V1::Accounts::N8nSpokeConfigsController < Api::V1::Accounts::N8nSettingsController
  private

  def settings_model
    N8nSpokeConfig
  end

  def resource_param
    :n8n_spoke_config
  end

  def serialized_attributes
    %i[
      id name description parameters api_template response_template output_template
      ai_data_request_instruction ai_output_instruction is_active created_at updated_at
    ]
  end

  def permitted_params
    permit_resource_params(
      scalar_fields: %i[
        name description api_template output_template ai_data_request_instruction
        ai_output_instruction is_active
      ],
      json_fields: %i[parameters response_template]
    )
  end
end
