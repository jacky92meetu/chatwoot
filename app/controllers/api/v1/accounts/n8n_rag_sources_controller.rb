class Api::V1::Accounts::N8nRagSourcesController < Api::V1::Accounts::N8nSettingsController
  MAX_SOURCES = 10

  def index
    render json: record_scope.order(:name).map { |record| serialize(record) }
  end

  def create
    return render json: { error: "You can add up to #{MAX_SOURCES} sources." }, status: :unprocessable_entity if record_scope.count >= MAX_SOURCES

    @record = record_scope.create!(build_attributes(nil))
    render_record(status: :created)
  end

  def update
    @record.update!(build_attributes(@record))
    render_record
  end

  private

  def settings_model
    N8nHubConfig
  end

  def record_scope
    super.where(config_type: 'rag_site')
  end

  def render_record(status: :ok)
    render json: serialize(@record), status: status
  end

  def serialize(record)
    config = record.value.presence || record.default_value
    {
      id: record.id, name: record.name, url: config['url'], enabled: config['enabled'] != false,
      exclude: Array(config['exclude']), max_pages: config['maxPages'], selector: config['selector'].to_s,
      pages: page_counts.fetch(record.id, 0), updated_at: record.updated_at
    }
  end

  # Pages indexed by the most recent successful run, matched back to each source.
  # Sources that run did not touch report zero.
  def page_counts
    @page_counts ||= begin
      sites = latest_indexed_sites
      record_scope.each_with_object({}) do |record, counts|
        site = matching_site(sites.keys, source_url(record))
        counts[record.id] = site ? sites[site] : 0
      end
    end
  end

  def latest_indexed_sites
    run = N8nRagRun.where(account_id: Current.account.id, status: 'success')
                   .where.not(per_site: nil).latest_first.first
    per_site = run&.per_site
    return {} unless per_site.is_a?(Hash)

    per_site.to_h { |site, data| [normalize_url(site), data.is_a?(Hash) ? data['pages'].to_i : data.to_i] }
  end

  # per_site keys are crawl origins, so a source may sit above or below the key.
  def matching_site(sites, source_url)
    return nil if source_url.blank?

    sites.find { |site| site == source_url } ||
      sites.find { |site| source_matches?(source_url, site) } ||
      sites.find { |site| source_matches?(site, source_url) }
  end

  def source_url(record)
    config = record.value.presence || record.default_value
    normalize_url(config['url'])
  end

  def normalize_url(value)
    value.to_s.strip.downcase.sub(%r{\A(https?://)www\.}, '\1').sub(%r{/+\z}, '')
  end

  def source_matches?(page_source, source_url)
    return false if source_url.blank?

    page_source == source_url || page_source.start_with?("#{source_url}/")
  end

  # Keeps keys this form does not manage (e.g. maxDepth) when editing an existing source.
  def build_attributes(record)
    raw = params.require(:n8n_rag_source)
    existing = record ? (record.value.presence || record.default_value) : {}
    config = existing.merge(
      'type' => 'rag_site', 'url' => raw[:url].to_s.strip, 'enabled' => ActiveModel::Type::Boolean.new.cast(raw[:enabled]) != false,
      'exclude' => Array(raw[:exclude]).map { |path| path.to_s.strip }.compact_blank.first(50),
      'maxPages' => raw[:max_pages].presence && raw[:max_pages].to_i, 'selector' => raw[:selector].to_s.strip
    ).compact
    { name: raw[:name].to_s.strip, config_type: 'rag_site', default_value: config, value: config, is_active: true }
  end
end
