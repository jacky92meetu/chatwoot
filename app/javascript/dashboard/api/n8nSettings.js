import ApiClient from './ApiClient';

class N8nSettingsAPI extends ApiClient {
  constructor(resource) {
    super(resource, { accountScoped: true });
  }
}

export const n8nHubConfigsAPI = new N8nSettingsAPI('n8n_hub_configs');
export const n8nHubGlobalVarsAPI = new N8nSettingsAPI('n8n_hub_global_vars');
export const n8nSpokeConfigsAPI = new N8nSettingsAPI('n8n_spoke_configs');
export const n8nRagSourcesAPI = new N8nSettingsAPI('n8n_rag_sources');
export const n8nRagRunsAPI = new N8nSettingsAPI('n8n_rag_runs');
