module Llm::ChatsHelper
  def chat_group_label(date)
    case date
    when Date.current then "Today"
    when Date.yesterday then "Yesterday"
    when 7.days.ago.to_date..Date.current then "Previous 7 days"
    else date.strftime("%B %Y")
    end
  end
end
