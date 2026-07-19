class WhatsappReplyJob < ApplicationJob
  def perform(to, body)
    Whatsapp::Client.send_text(to: to, body: body)
  end
end
