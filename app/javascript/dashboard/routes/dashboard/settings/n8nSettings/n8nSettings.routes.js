import { frontendURL } from '../../../../helper/URLHelper';

import SettingsWrapper from '../SettingsWrapper.vue';
import Index from './Index.vue';

const buildRoute = ({ path, name, resource }) => ({
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
  ],
};
