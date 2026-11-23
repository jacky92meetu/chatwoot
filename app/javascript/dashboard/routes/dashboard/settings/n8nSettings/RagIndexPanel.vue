<script setup>
import { computed, onBeforeUnmount, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { n8nRagRunsAPI } from 'dashboard/api/n8nSettings';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  hasSources: { type: Boolean, default: false },
});
const emit = defineEmits(['finished']);

const { t } = useI18n();
const POLL_MS = 5000;

const runs = ref([]);
const stats = ref({ chunks: 0, pages: 0, sites: [] });
const isRunning = ref(false);
const isStarting = ref(false);
let timer = null;

const latest = computed(() => runs.value[0]);

const errorMessage = error =>
  error?.response?.data?.error ||
  error?.response?.data?.message ||
  t('N8N_SETTINGS.API.ERROR');

const stopPolling = () => {
  clearTimeout(timer);
  timer = null;
};

const load = async () => {
  const wasRunning = isRunning.value;
  try {
    const { data } = await n8nRagRunsAPI.get();
    runs.value = data.runs;
    stats.value = data.stats;
    isRunning.value = data.running;
  } catch (error) {
    useAlert(errorMessage(error));
  }
  if (isRunning.value) {
    timer = setTimeout(load, POLL_MS);
  } else if (wasRunning) {
    emit('finished');
  }
};

const start = async () => {
  isStarting.value = true;
  try {
    await n8nRagRunsAPI.create({});
    useAlert(t('N8N_SETTINGS.RAG.PANEL.STARTED'));
  } catch (error) {
    useAlert(errorMessage(error));
  } finally {
    isStarting.value = false;
  }
  stopPolling();
  isRunning.value = true;
  await load();
};

const statusLabel = status =>
  ({
    success: 'N8N_SETTINGS.RAG.PANEL.SUCCESS',
    failed: 'N8N_SETTINGS.RAG.PANEL.FAILED',
    running: 'N8N_SETTINGS.RAG.PANEL.RUNNING_STATUS',
  })[status];

const statusClass = status =>
  ({
    success: 'bg-n-teal-3 text-n-teal-11',
    failed: 'bg-n-ruby-3 text-n-ruby-11',
    running: 'bg-n-amber-3 text-n-amber-11',
  })[status];

const formatTime = value => (value ? new Date(value).toLocaleString() : '—');

onMounted(load);
onBeforeUnmount(stopPolling);
</script>

<template>
  <div class="flex flex-col gap-4 p-4 mb-4 border rounded-xl border-n-weak">
    <div class="flex flex-wrap items-center justify-between gap-4">
      <div class="flex gap-8">
        <div>
          <p class="mb-0 text-xs text-n-slate-11">
            {{ t('N8N_SETTINGS.RAG.PANEL.PAGES') }}
          </p>
          <p class="mb-0 text-xl font-medium text-n-slate-12">
            {{ stats.pages }}
          </p>
        </div>
        <div>
          <p class="mb-0 text-xs text-n-slate-11">
            {{ t('N8N_SETTINGS.RAG.PANEL.CHUNKS') }}
          </p>
          <p class="mb-0 text-xl font-medium text-n-slate-12">
            {{ stats.chunks }}
          </p>
        </div>
      </div>
      <div class="flex flex-col items-end gap-1">
        <Button
          icon="i-lucide-refresh-cw"
          :label="
            t(
              isRunning
                ? 'N8N_SETTINGS.RAG.PANEL.RUNNING'
                : 'N8N_SETTINGS.RAG.PANEL.START'
            )
          "
          :is-loading="isRunning || isStarting"
          :disabled="isRunning || isStarting || !props.hasSources"
          @click="start"
        />
        <p v-if="!props.hasSources" class="mb-0 text-xs text-n-slate-11">
          {{ t('N8N_SETTINGS.RAG.PANEL.NEEDS_SOURCE') }}
        </p>
      </div>
    </div>

    <div
      v-if="latest && latest.status === 'failed'"
      class="p-3 text-sm rounded-lg bg-n-ruby-3 text-n-ruby-11 break-words"
    >
      {{ latest.error }}
    </div>

    <div>
      <p class="mb-2 text-sm font-medium text-n-slate-12">
        {{ t('N8N_SETTINGS.RAG.PANEL.HISTORY') }}
      </p>
      <p v-if="!runs.length" class="mb-0 text-sm text-n-slate-11">
        {{ t('N8N_SETTINGS.RAG.PANEL.NO_RUNS') }}
      </p>
      <ul v-else class="flex flex-col gap-2 pl-0 mb-0 list-none">
        <li
          v-for="run in runs"
          :key="run.id"
          class="flex flex-col gap-1 p-2 text-sm rounded-lg bg-n-alpha-1"
        >
          <div class="flex flex-wrap items-center gap-3">
            <span
              class="px-2 py-0.5 text-xs font-medium rounded-md"
              :class="statusClass(run.status)"
            >
              {{ t(statusLabel(run.status)) }}
            </span>
            <span class="text-n-slate-11">{{ formatTime(run.started_at) }}</span>
            <span v-if="run.status === 'success'" class="text-n-slate-12">
              {{
                t('N8N_SETTINGS.RAG.PANEL.RESULT', {
                  pages: run.pages,
                  chunks: run.chunks,
                  seconds: run.duration_seconds ?? 0,
                })
              }}
            </span>
            <span v-if="run.added_count" class="text-n-teal-11">
              {{ t('N8N_SETTINGS.RAG.PANEL.ADDED', { count: run.added_count }) }}
            </span>
            <span v-if="run.removed_count" class="text-n-ruby-11">
              {{
                t('N8N_SETTINGS.RAG.PANEL.REMOVED', {
                  count: run.removed_count,
                })
              }}
            </span>
          </div>
          <p
            v-if="run.status === 'failed' && run.error"
            class="mb-0 text-xs break-words text-n-slate-11"
          >
            {{ run.error }}
          </p>
        </li>
      </ul>
    </div>
  </div>
</template>
