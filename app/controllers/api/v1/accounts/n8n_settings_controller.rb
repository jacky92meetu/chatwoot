class Api::V1::Accounts::N8nSettingsController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?
  before_action :fetch_record, only: %i[show update destroy]

  def index
    render json: record_scope.order(:name).as_json(only: serialized_attributes)
  end

  def show
    render_record
  end

  def create
    @record = record_scope.create!(permitted_params)
    render_record(status: :created)
  end

  def update
    @record.update!(permitted_params)
    render_record
  end

  def destroy
    @record.destroy!
    head :no_content
  end

  private

  def record_scope
    settings_model.where(account_id: Current.account.id)
  end

  def fetch_record
    @record = record_scope.find(params[:id])
  end

  def render_record(status: :ok)
    render json: @record.as_json(only: serialized_attributes), status: status
  end

  def permit_resource_params(scalar_fields:, json_fields: [])
    raw_params = params.require(resource_param)
    permitted = raw_params.permit(*scalar_fields)

    json_fields.each do |field|
      permitted[field] = normalize_json_param(raw_params[field]) if raw_params.key?(field)
    end

    permitted
  end

  def normalize_json_param(value)
    case value
    when ActionController::Parameters
      value.to_unsafe_h
    when Array
      value.map { |item| normalize_json_param(item) }
    else
      value
    end
  end
end
