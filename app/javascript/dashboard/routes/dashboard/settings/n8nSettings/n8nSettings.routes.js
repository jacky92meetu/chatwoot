import { frontendURL } from '../../../../helper/URLHelper';
import store from '../../../../store';

import SettingsWrapper from '../SettingsWrapper.vue';
import Index from './Index.vue';

const superAdminOnly = (to, from, next) => {
  if (store.getters.getCurrentUser?.type === 'SuperAdmin') {
    next();
  } else {
    next({ name: 'general_settings_index', params: to.params });
  }
};

const buildRoute = ({ path, name, resource, beforeEnter }) => ({
  path: frontendURL(`accounts/:accountId/settings/${path}`),
  component: SettingsWrapper,
  children: [
    {
      path: '',
      name,
      meta: {
        permissions: ['administrator'],
        n8nResource: resource,
      },
      beforeEnter,
      component: Index,
    },
  ],
});

export default {
  routes: [
    buildRoute({
      path: 'hub-configs',
      name: 'n8n_hub_configs',
      resource: 'hubConfigs',
      beforeEnter: superAdminOnly,
    }),
    buildRoute({
      path: 'hub-global-vars',
      name: 'n8n_hub_global_vars',
      resource: 'globalVars',
    }),
    buildRoute({
      path: 'spoke-configs',
      name: 'n8n_spoke_configs',
      resource: 'spokeConfigs',
    }),
    buildRoute({
      path: 'rag',
      name: 'n8n_rag',
      resource: 'ragSources',
    }),
  ],
};
