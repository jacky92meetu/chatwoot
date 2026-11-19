class Api::V1::Accounts::N8nRagRunsController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?

  RUN_LIMIT = 10
  PAGE_PREVIEW_LIMIT = 20

  def index
    N8nRagRun.expire_stale!(Current.account.id, batch: engine_value['embeddingBatchModel'].present?)
    runs = N8nRagRun.where(account_id: Current.account.id).latest_first.limit(RUN_LIMIT).to_a
    render json: { runs: serialize_runs(runs), stats: stats, engine: engine, running: runs.any? { |run| run.status == 'running' } }
  end

  def create
    run = N8n::RagIndexer.new(Current.account, Current.user).start!
    render json: serialize_run(run, nil), status: :accepted
  rescue N8n::RagIndexer::Error => e
    render json: { error: e.message }, status: e.status
  end

  private

  def serialize_runs(runs)
    runs.each_with_index.map do |run, index|
      previous = runs.drop(index + 1).find { |candidate| candidate.status == 'success' }
      serialize_run(run, previous)
    end
  end

  def serialize_run(run, previous)
    added, removed = page_changes(run, previous)
    run.as_json(only: %i[id status started_at finished_at pages chunks per_site error]).merge(
      duration_seconds: run.duration_seconds,
      added_pages: added.first(PAGE_PREVIEW_LIMIT), added_count: added.size,
      removed_pages: removed.first(PAGE_PREVIEW_LIMIT), removed_count: removed.size
    )
  end

  def page_changes(run, previous)
    return [[], []] unless run.status == 'success' && previous

    current = Array(run.page_list)
    before = Array(previous.page_list)
    [current - before, before - current]
  end

  def stats
    account_id = Current.account.id
    totals = connection.select_one(sanitize('SELECT count(*) AS chunks, count(DISTINCT metadata->>\'source\') AS pages FROM n8n_docs WHERE account_id = ?', account_id))
    sites = connection.select_all(sanitize(<<~SQL.squish, account_id)).to_a
      SELECT metadata->>'site' AS site, count(DISTINCT metadata->>'source') AS pages, count(*) AS chunks
      FROM n8n_docs WHERE account_id = ? GROUP BY 1 ORDER BY 1
    SQL
    { chunks: totals['chunks'].to_i, pages: totals['pages'].to_i, sites: sites }
  end

  def engine
    engine_value.slice('engine', 'embeddingModel', 'chatModel', 'topK')
  end

  def engine_value
    @engine_value ||= begin
      record = N8nHubConfig.find_by(account_id: Current.account.id, config_type: 'rag_engine', is_active: true)
      record ? (record.value.presence || record.default_value) : {}
    end
  end

  def connection
    N8nRagRun.connection
  end

  def sanitize(sql, *binds)
    N8nRagRun.sanitize_sql_array([sql, *binds])
  end
end
