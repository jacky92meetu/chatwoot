class N8nRagRun < ApplicationRecord
  self.table_name = 'n8n_rag_index_runs'

  STATUSES = %w[running success failed].freeze
  STALE_AFTER = 2.hours
  STALE_AFTER_BATCH = 26.hours
  MIN_INTERVAL = 5.minutes

  belongs_to :account

  scope :running, -> { where(status: 'running') }
  scope :latest_first, -> { order(id: :desc) }

  # A run that never reported back (n8n restarted, webhook lost) must not block new runs forever.
  def self.expire_stale!(account_id, batch: false)
    limit = batch ? STALE_AFTER_BATCH : STALE_AFTER
    running.where(account_id: account_id).where(started_at: ...limit.ago).update_all(
      status: 'failed', finished_at: Time.current, error: 'The run did not finish in time and was marked as failed.'
    )
  end

  def duration_seconds
    return nil unless finished_at

    (finished_at - started_at).round
  end
end
