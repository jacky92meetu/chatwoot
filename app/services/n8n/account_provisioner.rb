# Sets up a customer account for the shared n8n Hub Router.
# The template account (N8N_TEMPLATE_ACCOUNT_ID, default 1) must already have an n8n_tenant_routes row;
# its bot becomes the single global bot and its Hub Config rows are cloned once into new accounts by the database trigger.
# Without a template route this service does nothing, so plain Chatwoot installs are unaffected.
class N8n::AccountProvisioner
  SERVICE_USER_EMAIL = 'n8n-hub@system.local'.freeze

  def initialize(account)
    @account = account
  end

  def self.template_account_id
    ENV.fetch('N8N_TEMPLATE_ACCOUNT_ID', 1).to_i
  end

  def self.template_route
    N8nTenantRoute.find_by(account_id: template_account_id)
  end

  # Without an inbox, the bot is attached to every inbox of the account that has no bot yet.
  def perform(inbox: nil)
    return false unless template_route

    @account.with_lock do
      provision_account unless N8nTenantRoute.exists?(account_id: @account.id)
      inboxes = inbox ? [inbox] : @account.inboxes.includes(:agent_bot_inbox)
      inboxes.each { |record| attach_bot(record) }
    end
    true
  end

  private

  def template_route
    @template_route ||= self.class.template_route
  end

  def provision_account
    N8nTenantRoute.create!(
      account_id: @account.id,
      chatwoot_api_workflow_id: template_route.chatwoot_api_workflow_id,
      chatwoot_base_url: template_route.chatwoot_base_url,
      bot_api_token: global_bot.access_token.token,
      agent_api_token: service_user_token
    )
  end

  def attach_bot(inbox)
    return if inbox.agent_bot_inbox.present?

    AgentBotInbox.create!(inbox: inbox, agent_bot: global_bot)
  end

  # The template account's bot is promoted once to a global bot so every tenant shares one webhook and token.
  def global_bot
    @global_bot ||= begin
      bot = AccessToken.find_by!(token: template_route.bot_api_token, owner_type: 'AgentBot').owner
      bot.update!(account_id: nil) unless bot.account_id.nil?
      bot
    end
  end

  def service_user_token
    user = User.find_by(email: SERVICE_USER_EMAIL) || create_service_user
    AccountUser.find_or_create_by!(account: @account, user: user) { |account_user| account_user.role = :administrator }
    user.access_token.token
  end

  def create_service_user
    User.new(name: 'n8n Hub', email: SERVICE_USER_EMAIL, password: "#{SecureRandom.hex(16)}Aa1!").tap do |user|
      user.skip_confirmation!
      user.save!
    end
  end
end
