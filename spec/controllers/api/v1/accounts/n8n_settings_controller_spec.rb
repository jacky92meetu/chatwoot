require 'rails_helper'

RSpec.describe 'n8n settings APIs', type: :request do
  let!(:account) { create(:account) }
  let!(:other_account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:admin_headers) { admin.create_new_auth_token }
  let(:super_admin) do
    create(:super_admin).tap { |user| create(:account_user, account: account, user: user, role: :administrator) }
  end
  let(:super_admin_headers) { super_admin.create_new_auth_token }

  describe 'authorization and tenant isolation' do
    let!(:hub_config) do
      N8nHubConfig.create!(
        account: other_account,
        config_type: 'setting',
        name: 'other_account_setting',
        default_value: { 'name' => 'other_account_setting', 'value' => true }
      )
    end

    it 'rejects unauthenticated requests' do
      get "/api/v1/accounts/#{account.id}/n8n_hub_configs"

      expect(response).to have_http_status(:unauthorized)
    end

    it 'rejects non-administrators' do
      get "/api/v1/accounts/#{account.id}/n8n_hub_configs", headers: agent.create_new_auth_token

      expect(response).to have_http_status(:unauthorized)
    end

    it 'rejects account administrators who are not super admins for hub configs' do
      get "/api/v1/accounts/#{account.id}/n8n_hub_configs", headers: admin_headers

      expect(response).to have_http_status(:unauthorized)
    end

    it 'does not expose records belonging to another account' do
      get "/api/v1/accounts/#{account.id}/n8n_hub_configs/#{hub_config.id}", headers: super_admin_headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'hub configs' do
    let(:payload) do
      {
        n8n_hub_config: {
          config_type: 'setting',
          name: 'new_setting',
          value: nil,
          default_value: { name: 'new_setting', type: 'setting', value: true },
          description: 'A setting managed in Chatwoot',
          is_active: true
        }
      }
    end

    it 'creates, updates, lists, and deletes account-scoped records' do
      expect do
        post "/api/v1/accounts/#{account.id}/n8n_hub_configs", params: payload, headers: super_admin_headers, as: :json
      end.to change { N8nHubConfig.where(account_id: account.id).count }.by(1)

      expect(response).to have_http_status(:created)
      record_id = response.parsed_body['id']

      patch "/api/v1/accounts/#{account.id}/n8n_hub_configs/#{record_id}",
            params: { n8n_hub_config: { description: 'Updated' } },
            headers: super_admin_headers,
            as: :json
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['description']).to eq('Updated')

      get "/api/v1/accounts/#{account.id}/n8n_hub_configs", headers: super_admin_headers
      expect(response.parsed_body.pluck('id')).to include(record_id)

      expect do
        delete "/api/v1/accounts/#{account.id}/n8n_hub_configs/#{record_id}", headers: super_admin_headers
      end.to change(N8nHubConfig, :count).by(-1)
      expect(response).to have_http_status(:no_content)
    end
  end

  describe 'hub global variables' do
    let(:payload) do
      {
        n8n_hub_global_var: {
          name: 'API_URL',
          value: 'https://example.test',
          description: 'Shared API URL',
          is_secret: false,
          is_active: true
        }
      }
    end

    it 'creates an account-scoped JSON value' do
      post "/api/v1/accounts/#{account.id}/n8n_hub_global_vars",
           params: payload,
           headers: admin_headers,
           as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to include('name' => 'API_URL', 'value' => 'https://example.test')
      expect(N8nHubGlobalVar.find(response.parsed_body['id']).account_id).to eq(account.id)
    end
  end

  describe 'rag sources' do
    let!(:source) do
      N8nHubConfig.create!(
        account: account,
        config_type: 'rag_site',
        name: 'main_site',
        default_value: { 'type' => 'rag_site', 'url' => 'https://example.test', 'enabled' => true },
        is_active: true
      )
    end

    it 'reports the page count from the latest successful run' do
      N8nRagRun.create!(
        account: account,
        status: 'success',
        started_at: 1.hour.ago,
        finished_at: 1.hour.ago,
        pages: 7,
        chunks: 21,
        per_site: { 'https://example.test' => { 'pages' => 7, 'chunks' => 21 } }
      )

      get "/api/v1/accounts/#{account.id}/n8n_rag_sources", headers: admin_headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to contain_exactly(
        include('id' => source.id, 'name' => 'main_site', 'pages' => 7)
      )
      expect(response.parsed_body.first).not_to have_key('chunks')
    end

    it 'reports zero pages before any successful run' do
      get "/api/v1/accounts/#{account.id}/n8n_rag_sources", headers: admin_headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to contain_exactly(
        include('id' => source.id, 'name' => 'main_site', 'pages' => 0)
      )
    end
  end

  describe 'spoke configs' do
    let(:payload) do
      {
        n8n_spoke_config: {
          name: 'order_status',
          description: 'Retrieve an order',
          parameters: { order_id: { required: true } },
          api_template: 'GET {{URL}}/orders/{{order_id}}',
          response_template: { status: '{{response.status}}' },
          output_template: 'Status: {{status}}',
          ai_data_request_instruction: 'Collect the order ID.',
          ai_output_instruction: 'Answer concisely.',
          is_active: true
        }
      }
    end

    it 'creates an account-scoped spoke' do
      post "/api/v1/accounts/#{account.id}/n8n_spoke_configs",
           params: payload,
           headers: admin_headers,
           as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to include('name' => 'order_status')
      expect(N8nSpokeConfig.find(response.parsed_body['id']).account_id).to eq(account.id)
    end
  end
end
