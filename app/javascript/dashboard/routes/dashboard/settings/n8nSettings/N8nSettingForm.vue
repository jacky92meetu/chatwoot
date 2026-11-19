<script setup>
/* eslint-disable @intlify/vue-i18n/no-dynamic-keys */
import { reactive, watch } from 'vue';
import { useI18n } from 'vue-i18n';

import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import { serializeJson } from './resourceConfig';

const props = defineProps({
  resourceConfig: {
    type: Object,
    required: true,
  },
  record: {
    type: Object,
    default: null,
  },
  isSaving: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['cancel', 'submit']);
const { t } = useI18n();

const form = reactive({});
const errors = reactive({});

const initialValue = field => {
  if (props.record && Object.hasOwn(props.record, field.key)) {
    const value = props.record[field.key];
    if (field.type.startsWith('json')) {
      return value === null ? '' : serializeJson(value);
    }
    if (field.type === 'boolean') {
      return value ?? field.defaultValue ?? false;
    }
    return value ?? '';
  }

  if (field.type.startsWith('json')) {
    if (field.defaultValue !== undefined) {
      return serializeJson(field.defaultValue);
    }
    return '';
  }

  return field.defaultValue ?? '';
};

const resetForm = () => {
  Object.keys(form).forEach(key => delete form[key]);
  Object.keys(errors).forEach(key => delete errors[key]);
  props.resourceConfig.fields.forEach(field => {
    form[field.key] = initialValue(field);
  });
};

watch(() => props.record, resetForm, { immediate: true });

const parseField = field => {
  const value = form[field.key];

  if (field.type.startsWith('json')) {
    if (!String(value).trim()) {
      if (field.required) {
        errors[field.key] = t('N8N_SETTINGS.VALIDATION.REQUIRED');
        return { valid: false };
      }
      return { valid: true, value: null };
    }

    try {
      const parsed = JSON.parse(value);
      if (
        field.type === 'jsonObject' &&
        (parsed === null || Array.isArray(parsed) || typeof parsed !== 'object')
      ) {
        errors[field.key] = t('N8N_SETTINGS.VALIDATION.JSON_OBJECT');
        return { valid: false };
      }
      if (field.required && parsed === null) {
        errors[field.key] = t('N8N_SETTINGS.VALIDATION.NON_NULL_JSON');
        return { valid: false };
      }
      return { valid: true, value: parsed };
    } catch {
      errors[field.key] = t('N8N_SETTINGS.VALIDATION.JSON');
      return { valid: false };
    }
  }

  if (field.required && !String(value).trim()) {
    errors[field.key] = t('N8N_SETTINGS.VALIDATION.REQUIRED');
    return { valid: false };
  }

  return { valid: true, value };
};

const submit = () => {
  Object.keys(errors).forEach(key => delete errors[key]);
  const payload = {};
  let valid = true;

  props.resourceConfig.fields.forEach(field => {
    const result = parseField(field);
    valid = valid && result.valid;
    if (result.valid) payload[field.key] = result.value;
  });

  if (valid) emit('submit', payload);
};
</script>

<template>
  <div class="flex flex-col max-h-[90vh]">
    <woot-modal-header
      :header-title="
        t(
          record
            ? 'N8N_SETTINGS.FORM.EDIT_TITLE'
            : 'N8N_SETTINGS.FORM.ADD_TITLE',
          { resource: t(resourceConfig.singular) }
        )
      "
    />

    <form
      class="flex flex-col gap-5 px-8 pb-6 overflow-y-auto"
      @submit.prevent="submit"
    >
      <template v-for="field in resourceConfig.fields" :key="field.key">
        <Input
          v-if="field.type === 'text'"
          v-model="form[field.key]"
          :label="t(field.label)"
          :message="errors[field.key] || (field.hint ? t(field.hint) : '')"
          :message-type="errors[field.key] ? 'error' : 'info'"
        />

        <div v-else-if="field.type === 'select'" class="flex flex-col gap-1">
          <label class="mb-0.5 text-heading-3 text-n-slate-12">
            {{ t(field.label) }}
          </label>
          <Select
            v-model="form[field.key]"
            :options="field.options"
            :error="errors[field.key]"
            class="w-full [&>select]:w-full"
          />
          <p v-if="errors[field.key]" class="mb-0 text-xs text-n-ruby-9">
            {{ errors[field.key] }}
          </p>
        </div>

        <TextArea
          v-else-if="field.type === 'textarea' || field.type.startsWith('json')"
          v-model="form[field.key]"
          :label="t(field.label)"
          :message="errors[field.key] || (field.hint ? t(field.hint) : '')"
          :message-type="errors[field.key] ? 'error' : 'info'"
          auto-height
          resize
          :min-height="field.type.startsWith('json') ? '8rem' : '5rem'"
          max-height="20rem"
          :custom-text-area-class="
            field.type.startsWith('json') ? 'font-mono' : ''
          "
        />

        <div
          v-else-if="field.type === 'boolean'"
          class="flex items-start justify-between gap-4"
        >
          <div>
            <p class="mb-0 text-sm font-medium text-n-slate-12">
              {{ t(field.label) }}
            </p>
            <p v-if="field.hint" class="mt-1 mb-0 text-xs text-n-slate-11">
              {{ t(field.hint) }}
            </p>
          </div>
          <Switch v-model="form[field.key]" />
        </div>
      </template>

      <div class="flex justify-end gap-2 pt-2">
        <Button
          type="button"
          faded
          slate
          :label="t('N8N_SETTINGS.FORM.CANCEL')"
          @click="emit('cancel')"
        />
        <Button
          type="submit"
          :is-loading="isSaving"
          :disabled="isSaving"
          :label="
            t(record ? 'N8N_SETTINGS.FORM.UPDATE' : 'N8N_SETTINGS.FORM.CREATE')
          "
        />
      </div>
    </form>
  </div>
</template>
