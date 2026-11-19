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
      updated_at: record.updated_at
    }
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
