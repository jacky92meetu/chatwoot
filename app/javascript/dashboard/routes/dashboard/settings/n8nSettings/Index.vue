<script setup>
/* eslint-disable @intlify/vue-i18n/no-dynamic-keys */
import { computed, onMounted, ref } from 'vue';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';

import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import {
  BaseTable,
  BaseTableCell,
  BaseTableRow,
} from 'dashboard/components-next/table';
import N8nSettingForm from './N8nSettingForm.vue';
import RagIndexPanel from './RagIndexPanel.vue';
import { RESOURCE_CONFIGS, truncateValue } from './resourceConfig';

const route = useRoute();
const { t } = useI18n();

const resourceConfig = computed(() => RESOURCE_CONFIGS[route.meta.n8nResource]);
const records = ref([]);
const isLoading = ref(false);
const isSaving = ref(false);
const searchQuery = ref('');
const selectedRecord = ref(null);
const recordToDelete = ref(null);
const showForm = ref(false);
const showDeleteConfirmation = ref(false);

const filteredRecords = computed(() => {
  const query = searchQuery.value.trim().toLowerCase();
  if (!query) return records.value;

  return records.value.filter(record =>
    JSON.stringify(record).toLowerCase().includes(query)
  );
});

const tableHeaders = computed(() => [
  ...resourceConfig.value.columns.map(column => t(column.label)),
  t('N8N_SETTINGS.FIELDS.ACTIONS'),
]);

const apiErrorMessage = error => {
  const data = error?.response?.data;
  if (Array.isArray(data?.errors)) return data.errors.join(', ');
  return data?.message || data?.error || t('N8N_SETTINGS.API.ERROR');
};

const fetchRecords = async () => {
  isLoading.value = true;
  try {
    const response = await resourceConfig.value.api.get();
    records.value = response.data;
  } catch (error) {
    useAlert(apiErrorMessage(error));
  } finally {
    isLoading.value = false;
  }
};

const openCreateForm = () => {
  selectedRecord.value = null;
  showForm.value = true;
};

const openEditForm = record => {
  selectedRecord.value = record;
  showForm.value = true;
};

const closeForm = () => {
  showForm.value = false;
  selectedRecord.value = null;
};

const saveRecord = async values => {
  isSaving.value = true;
  const config = resourceConfig.value;
  const payload = { [config.paramKey]: values };

  try {
    if (selectedRecord.value) {
      await config.api.update(selectedRecord.value.id, payload);
      useAlert(t('N8N_SETTINGS.API.UPDATE_SUCCESS'));
    } else {
      await config.api.create(payload);
      useAlert(t('N8N_SETTINGS.API.CREATE_SUCCESS'));
    }
    closeForm();
    await fetchRecords();
  } catch (error) {
    useAlert(apiErrorMessage(error));
  } finally {
    isSaving.value = false;
  }
};

const requestDelete = record => {
  recordToDelete.value = record;
  showDeleteConfirmation.value = true;
};

const closeDeleteConfirmation = () => {
  showDeleteConfirmation.value = false;
};

const deleteRecord = async () => {
  try {
    await resourceConfig.value.api.delete(recordToDelete.value.id);
    records.value = records.value.filter(
      record => record.id !== recordToDelete.value.id
    );
    useAlert(t('N8N_SETTINGS.API.DELETE_SUCCESS'));
  } catch (error) {
    useAlert(apiErrorMessage(error));
  } finally {
    closeDeleteConfirmation();
    recordToDelete.value = null;
  }
};

const displayValue = (record, column) => {
  if (column.type === 'effectiveJson') {
    return truncateValue(record.value ?? record.default_value);
  }
  if (column.type === 'secretJson' && record.is_secret) {
    return '••••••••';
  }
  if (column.type === 'json') return truncateValue(record[column.key]);
  if (column.type === 'text') return truncateValue(record[column.key]);
  return record[column.key] || '—';
};

const booleanLabel = (record, column) => {
  if (column.key === 'is_secret') {
    return record[column.key] ? 'N8N_SETTINGS.YES' : 'N8N_SETTINGS.NO';
  }

  return record[column.key] ? 'N8N_SETTINGS.ACTIVE' : 'N8N_SETTINGS.INACTIVE';
};

onMounted(fetchRecords);
</script>

<template>
  <SettingsLayout
    :is-loading="isLoading"
    :loading-message="t('N8N_SETTINGS.LOADING')"
    :no-records-found="!isLoading && !records.length"
    :no-records-message="t('N8N_SETTINGS.NO_RECORDS')"
  >
    <template #header>
      <BaseSettingsHeader
        v-model:search-query="searchQuery"
        :title="t(resourceConfig.title)"
        :description="t(resourceConfig.description)"
        :search-placeholder="t('N8N_SETTINGS.SEARCH')"
      >
        <template #count>
          <span class="text-body-main text-n-slate-11">
            {{ t('N8N_SETTINGS.COUNT', { count: records.length }) }}
          </span>
        </template>
        <template #actions>
          <Button
            size="sm"
            icon="i-lucide-plus"
            :label="
              t('N8N_SETTINGS.ADD', {
                resource: t(resourceConfig.singular),
              })
            "
            @click="openCreateForm"
          />
        </template>
      </BaseSettingsHeader>
    </template>

    <template v-if="resourceConfig.panel === 'rag'" #preBody>
      <RagIndexPanel
        :has-sources="records.some(record => record.enabled)"
        @finished="fetchRecords"
      />
    </template>

    <template #body>
      <BaseTable
        :headers="tableHeaders"
        :items="filteredRecords"
        :no-data-message="t('N8N_SETTINGS.NO_RESULTS')"
      >
        <template #row="{ items }">
          <BaseTableRow v-for="record in items" :key="record.id" :item="record">
            <BaseTableCell
              v-for="column in resourceConfig.columns"
              :key="column.key"
            >
              <span
                v-if="column.type === 'boolean'"
                class="inline-flex px-2 py-0.5 rounded-md text-xs font-medium"
                :class="
                  record[column.key]
                    ? 'bg-n-teal-3 text-n-teal-11'
                    : 'bg-n-slate-3 text-n-slate-11'
                "
              >
                {{ t(booleanLabel(record, column)) }}
              </span>
              <code
                v-else-if="
                  column.type === 'json' ||
                  column.type === 'effectiveJson' ||
                  column.type === 'secretJson'
                "
                class="text-xs break-all text-n-slate-11"
              >
                {{ displayValue(record, column) }}
              </code>
              <span v-else class="text-sm break-all text-n-slate-12">
                {{ displayValue(record, column) }}
              </span>
            </BaseTableCell>

            <BaseTableCell align="end">
              <div class="flex justify-end gap-2">
                <Button
                  v-tooltip.top="t('N8N_SETTINGS.EDIT')"
                  icon="i-woot-edit-pen"
                  slate
                  sm
                  @click="openEditForm(record)"
                />
                <Button
                  v-tooltip.top="t('N8N_SETTINGS.DELETE')"
                  icon="i-woot-bin"
                  ruby
                  faded
                  sm
                  @click="requestDelete(record)"
                />
              </div>
            </BaseTableCell>
          </BaseTableRow>
        </template>
      </BaseTable>
    </template>

    <woot-modal v-model:show="showForm" full-width :on-close="closeForm">
      <N8nSettingForm
        :resource-config="resourceConfig"
        :record="selectedRecord"
        :is-saving="isSaving"
        @cancel="closeForm"
        @submit="saveRecord"
      />
    </woot-modal>

    <woot-delete-modal
      v-model:show="showDeleteConfirmation"
      :on-close="closeDeleteConfirmation"
      :on-confirm="deleteRecord"
      :title="t('N8N_SETTINGS.DELETE_CONFIRM.TITLE')"
      :message="t('N8N_SETTINGS.DELETE_CONFIRM.MESSAGE')"
      :message-value="recordToDelete?.name || ''"
      :confirm-text="t('N8N_SETTINGS.DELETE_CONFIRM.YES')"
      :reject-text="t('N8N_SETTINGS.DELETE_CONFIRM.NO')"
    />
  </SettingsLayout>
</template>
