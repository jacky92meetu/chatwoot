class N8n::ProvisionAccountJob < ApplicationJob
  queue_as :default

  def perform(account, inbox = nil)
    N8n::AccountProvisioner.new(account).perform(inbox: inbox)
  end
end
