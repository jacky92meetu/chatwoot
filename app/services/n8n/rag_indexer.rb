require 'net/http'

# Starts a RAG re-index for one account by recording a run and asking the n8n "RAG re-index" workflow to execute it.
class N8n::RagIndexer
  class Error < StandardError
    attr_reader :status

    def initialize(message, status: :unprocessable_entity)
      super(message)
      @status = status
    end
  end

  def initialize(account, user)
    @account = account
    @user = user
  end

  def start!
    url = ENV.fetch('N8N_RAG_REINDEX_URL', nil)
    raise Error.new('RAG indexing is not configured on this server.', status: :service_unavailable) if url.blank?

    N8nRagRun.expire_stale!(@account.id, batch: batch_embeddings?)
    ensure_ready!
    run = create_run!
    trigger(url, run)
    run
  end

  private

  def ensure_ready!
    raise Error, 'The n8n hub is not set up for this account yet.' unless N8nTenantRoute.exists?(account_id: @account.id, is_active: true)
    raise Error, 'Add and enable at least one source before indexing.' unless enabled_sources?

    last = N8nRagRun.where(account_id: @account.id).latest_first.first
    return unless last && last.started_at > N8nRagRun::MIN_INTERVAL.ago

    wait = ((last.started_at + N8nRagRun::MIN_INTERVAL) - Time.current).ceil
    raise Error.new("Please wait #{wait} seconds before starting another run.", status: :too_many_requests)
  end

  def enabled_sources?
    N8nHubConfig.where(account_id: @account.id, config_type: 'rag_site', is_active: true).any? do |source|
      (source.value.presence || source.default_value)['enabled'] != false
    end
  end

  def batch_embeddings?
    engine = N8nHubConfig.find_by(account_id: @account.id, config_type: 'rag_engine', is_active: true)
    engine.present? && (engine.value.presence || engine.default_value)['embeddingBatchModel'].present?
  end

  def create_run!
    N8nRagRun.create!(account_id: @account.id, status: 'running', started_at: Time.current, requested_by: @user&.id)
  rescue ActiveRecord::RecordNotUnique
    raise Error.new('An indexing run is already in progress.', status: :conflict)
  end

  def trigger(url, run)
    response = post(url, run)
    return if response.is_a?(Net::HTTPSuccess)

    fail_run(run, "n8n rejected the request (HTTP #{response.code}).")
  rescue Error
    raise
  rescue StandardError => e
    fail_run(run, "Could not reach n8n: #{e.class}.")
    Rails.logger.error("RAG index trigger failed for account #{@account.id}: #{e.message}")
  end

  def post(url, run)
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    http.open_timeout = 3
    http.read_timeout = 10
    request = Net::HTTP::Post.new(uri.request_uri, 'Content-Type' => 'application/json')
    request.body = { accountId: @account.id, runId: run.id }.to_json
    http.request(request)
  end

  def fail_run(run, message)
    run.update!(status: 'failed', finished_at: Time.current, error: message)
    raise Error.new(message, status: :bad_gateway)
  end
end
