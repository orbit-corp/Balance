require "test_helper"

class ExpenseReportTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    @bank = @workspace.accounts.create!(name: "Checking", base_type: "asset", account_type: "Cash & Liquid Assets", detail_type: "Checking Account")
    @fuel = @workspace.accounts.create!(name: "Fuel", base_type: "expense", account_type: "Personal Outflows", detail_type: "Transportation")
    @repairs = @workspace.accounts.create!(name: "Repairs", base_type: "expense", account_type: "Personal Outflows", detail_type: "Housing & Utilities")
    @vendor = @workspace.contacts.create!(name: "Energy Ltd", contact_kind: "business", email: "energy@example.com", role_names: %w[vendor])
  end

  test "summarizes posted expenses by month vendor and category" do
    create_posted_expense(amount_kobo: 40_000_00, category: @fuel, payment_date: Date.new(2026, 7, 10))
    create_posted_expense(amount_kobo: 10_000_00, category: @repairs, payment_date: Date.new(2026, 8, 10))

    report = ExpenseReport.new(@workspace, date_range: Date.new(2026, 7, 1)..Date.new(2026, 8, 31))

    assert_equal 50_000_00, report.total_kobo
    assert_equal({ Date.new(2026, 7, 1) => 40_000_00, Date.new(2026, 8, 1) => 10_000_00 }, report.monthly_totals)
    assert_equal [ [ "Energy Ltd", 50_000_00 ] ], report.top_vendors.map { |row| [ row.label, row.amount_kobo ] }
    assert_equal [ "Fuel", "Repairs" ], report.top_categories.map(&:label)
    assert_equal [ "Fuel", "Repairs" ], report.category_trends.map { |series| series[:name] }.sort
  end

  test "excludes drafts and applies vendor and category filters" do
    create_posted_expense(amount_kobo: 40_000_00, category: @fuel)
    other_vendor = @workspace.contacts.create!(name: "Garage Ltd", contact_kind: "business", email: "garage@example.com", role_names: %w[vendor])
    create_posted_expense(amount_kobo: 10_000_00, category: @repairs, vendor: other_vendor)
    create_expense(amount_kobo: 90_000_00, category: @fuel).save!

    report = ExpenseReport.new(
      @workspace,
      date_range: Date.current.beginning_of_month..Date.current,
      vendor_id: @vendor.id,
      category_id: @fuel.id
    )

    assert_equal 40_000_00, report.total_kobo
    assert_equal [ "Energy Ltd" ], report.top_vendors.map(&:label)
    assert_equal [ "Fuel" ], report.top_categories.map(&:label)
  end

  private
    def create_posted_expense(**attributes)
      create_expense(**attributes).tap do |expense|
        expense.save!
        assert expense.post.success?
      end
    end

    def create_expense(amount_kobo:, category:, vendor: @vendor, payment_date: Date.current)
      @workspace.expenses.build(
        payee_contact: vendor,
        payment_date: payment_date,
        payment_account: @bank,
        expense_lines_attributes: [
          { account: category, description: category.name, amount_kobo: amount_kobo, position: 0 }
        ]
      )
    end
end
