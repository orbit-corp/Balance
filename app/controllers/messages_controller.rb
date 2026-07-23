class MessagesController < ApplicationController
  include Pagy::Method

  PER_PAGE = 50

  def index
    scope = current_workspace.whatsapp_messages.inbound.order(sent_at: :desc, id: :desc)
    # :countless avoids a COUNT query on every load — this table only grows, and we only
    # ever need "is there another page", not a total.
    @pagy, fetched = pagy(:countless, scope, limit: PER_PAGE)

    @page = @pagy.page
    @has_more = @pagy.next.present?
    @messages = fetched.reverse
  end
end
