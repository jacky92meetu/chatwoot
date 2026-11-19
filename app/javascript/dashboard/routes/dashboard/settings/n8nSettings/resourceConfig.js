import {
  n8nHubConfigsAPI,
  n8nHubGlobalVarsAPI,
  n8nSpokeConfigsAPI,
} from 'dashboard/api/n8nSettings';

const CONFIG_TYPE_OPTIONS = [
  'intent',
  'spoke',
  'flowise',
  'rag_site',
  'model',
  'message',
  'instruction',
  'report',
  'rag_engine',
  'setting',
].map(value => ({ value, label: value }));

const activeField = {
  key: 'is_active',
  type: 'boolean',
  label: 'N8N_SETTINGS.FIELDS.IS_ACTIVE',
  defaultValue: true,
};

export const RESOURCE_CONFIGS = {
  hubConfigs: {
    api: n8nHubConfigsAPI,
    paramKey: 'n8n_hub_config',
    title: 'N8N_SETTINGS.HUB_CONFIGS.TITLE',
    description: 'N8N_SETTINGS.HUB_CONFIGS.DESCRIPTION',
    singular: 'N8N_SETTINGS.HUB_CONFIGS.SINGULAR',
    columns: [
      { key: 'name', label: 'N8N_SETTINGS.FIELDS.NAME' },
      { key: 'config_type', label: 'N8N_SETTINGS.FIELDS.CONFIG_TYPE' },
      {
        key: 'effective_value',
        label: 'N8N_SETTINGS.FIELDS.EFFECTIVE_VALUE',
        type: 'effectiveJson',
      },
      {
        key: 'is_active',
        label: 'N8N_SETTINGS.FIELDS.STATUS',
        type: 'boolean',
      },
    ],
    fields: [
      {
        key: 'name',
        type: 'text',
        label: 'N8N_SETTINGS.FIELDS.NAME',
        required: true,
      },
      {
        key: 'config_type',
        type: 'select',
        label: 'N8N_SETTINGS.FIELDS.CONFIG_TYPE',
        required: true,
        options: CONFIG_TYPE_OPTIONS,
      },
      {
        key: 'description',
        type: 'textarea',
        label: 'N8N_SETTINGS.FIELDS.DESCRIPTION',
      },
      {
        key: 'value',
        type: 'jsonObject',
        label: 'N8N_SETTINGS.FIELDS.VALUE_OVERRIDE',
        hint: 'N8N_SETTINGS.HINTS.OPTIONAL_OBJECT',
        nullable: true,
      },
      {
        key: 'default_value',
        type: 'jsonObject',
        label: 'N8N_SETTINGS.FIELDS.DEFAULT_VALUE',
        hint: 'N8N_SETTINGS.HINTS.REQUIRED_OBJECT',
        required: true,
        defaultValue: {},
      },
      activeField,
    ],
  },
  globalVars: {
    api: n8nHubGlobalVarsAPI,
    paramKey: 'n8n_hub_global_var',
    title: 'N8N_SETTINGS.GLOBAL_VARS.TITLE',
    description: 'N8N_SETTINGS.GLOBAL_VARS.DESCRIPTION',
    singular: 'N8N_SETTINGS.GLOBAL_VARS.SINGULAR',
    columns: [
      { key: 'name', label: 'N8N_SETTINGS.FIELDS.NAME' },
      {
        key: 'value',
        label: 'N8N_SETTINGS.FIELDS.VALUE',
        type: 'secretJson',
      },
      {
        key: 'is_secret',
        label: 'N8N_SETTINGS.FIELDS.SECRET',
        type: 'boolean',
      },
      {
        key: 'is_active',
        label: 'N8N_SETTINGS.FIELDS.STATUS',
        type: 'boolean',
      },
    ],
    fields: [
      {
        key: 'name',
        type: 'text',
        label: 'N8N_SETTINGS.FIELDS.NAME',
        hint: 'N8N_SETTINGS.HINTS.VARIABLE_NAME',
        required: true,
      },
      {
        key: 'value',
        type: 'json',
        label: 'N8N_SETTINGS.FIELDS.VALUE',
        hint: 'N8N_SETTINGS.HINTS.REQUIRED_JSON',
        required: true,
      },
      {
        key: 'description',
        type: 'textarea',
        label: 'N8N_SETTINGS.FIELDS.DESCRIPTION',
      },
      {
        key: 'is_secret',
        type: 'boolean',
        label: 'N8N_SETTINGS.FIELDS.SECRET',
        hint: 'N8N_SETTINGS.HINTS.SECRET',
        defaultValue: false,
      },
      activeField,
    ],
  },
  spokeConfigs: {
    api: n8nSpokeConfigsAPI,
    paramKey: 'n8n_spoke_config',
    title: 'N8N_SETTINGS.SPOKE_CONFIGS.TITLE',
    description: 'N8N_SETTINGS.SPOKE_CONFIGS.DESCRIPTION',
    singular: 'N8N_SETTINGS.SPOKE_CONFIGS.SINGULAR',
    columns: [
      { key: 'name', label: 'N8N_SETTINGS.FIELDS.NAME' },
      {
        key: 'api_template',
        label: 'N8N_SETTINGS.FIELDS.API_TEMPLATE',
        type: 'text',
      },
      {
        key: 'parameters',
        label: 'N8N_SETTINGS.FIELDS.PARAMETERS',
        type: 'json',
      },
      {
        key: 'is_active',
        label: 'N8N_SETTINGS.FIELDS.STATUS',
        type: 'boolean',
      },
    ],
    fields: [
      {
        key: 'name',
        type: 'text',
        label: 'N8N_SETTINGS.FIELDS.NAME',
        required: true,
      },
      {
        key: 'description',
        type: 'textarea',
        label: 'N8N_SETTINGS.FIELDS.DESCRIPTION',
      },
      {
        key: 'parameters',
        type: 'jsonObject',
        label: 'N8N_SETTINGS.FIELDS.PARAMETERS',
        hint: 'N8N_SETTINGS.HINTS.REQUIRED_OBJECT',
        required: true,
        defaultValue: {},
      },
      {
        key: 'api_template',
        type: 'textarea',
        label: 'N8N_SETTINGS.FIELDS.API_TEMPLATE',
        required: true,
      },
      {
        key: 'response_template',
        type: 'json',
        label: 'N8N_SETTINGS.FIELDS.RESPONSE_TEMPLATE',
        hint: 'N8N_SETTINGS.HINTS.OPTIONAL_JSON',
        nullable: true,
      },
      {
        key: 'output_template',
        type: 'textarea',
        label: 'N8N_SETTINGS.FIELDS.OUTPUT_TEMPLATE',
      },
      {
        key: 'ai_data_request_instruction',
        type: 'textarea',
        label: 'N8N_SETTINGS.FIELDS.AI_DATA_REQUEST_INSTRUCTION',
      },
      {
        key: 'ai_output_instruction',
        type: 'textarea',
        label: 'N8N_SETTINGS.FIELDS.AI_OUTPUT_INSTRUCTION',
      },
      activeField,
    ],
  },
};

export const serializeJson = value => JSON.stringify(value, null, 2);

export const truncateValue = (value, maxLength = 120) => {
  const text = typeof value === 'string' ? value : JSON.stringify(value);
  if (!text) return '—';
  return text.length > maxLength ? `${text.slice(0, maxLength)}…` : text;
};
