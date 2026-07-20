class MessagesController < ApplicationController
  def index
    @messages = current_workspace.whatsapp_messages.inbound.chronological
  end
end
