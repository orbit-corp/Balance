require "test_helper"

class CategoryTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
  end

  test "name must be unique per workspace and kind" do
    @workspace.categories.create!(kind: :income, name: "Sales")
    duplicate = @workspace.categories.build(kind: :income, name: "Sales")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
  end

  test "same name is allowed across different kinds" do
    @workspace.categories.create!(kind: :income, name: "Other")
    expense_other = @workspace.categories.build(kind: :expense, name: "Other")

    assert expense_other.valid?
  end

  test "same name is allowed across different workspaces" do
    @workspace.categories.create!(kind: :income, name: "Sales")
    other_workspace = workspaces(:bola_shop)
    same_name = other_workspace.categories.build(kind: :income, name: "Sales")

    assert same_name.valid?
  end

  test "seed_defaults_for creates the default income and expense categories" do
    Category.seed_defaults_for(@workspace)

    assert_equal %w[Other Sales], @workspace.categories.income.pluck(:name).sort
    assert_equal [ "Data/Airtime", "Fees", "Other", "Rent", "Restock", "Transport", "Utilities" ], @workspace.categories.expense.pluck(:name).sort
  end
end
