module ApplicationHelper
  def navigation_sections
    [
      { items: [
        { path: dashboard_path, svg: "icons/home.svg", text: "Dashboard" },
        { path: journal_entries_path, svg: "icons/list.svg", text: "Journal entries" },
        { path: accounts_path, svg: "icons/wallet.svg", text: "Accounts" },
        { path: chats_path, svg: "icons/bot.svg", text: "Agent" }
      ] },
      { label: "Records", items: [
        { path: customers_path, svg: "icons/users.svg", text: "Customers" }
      ] }
    ]
  end

  def active_nav?(path)
    return current_page?(root_path) || current_page?(dashboard_path) if path == dashboard_path

    current_page?(path) || request.path.start_with?("#{path}/")
  end
end
