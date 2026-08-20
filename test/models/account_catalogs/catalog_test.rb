require "test_helper"

class AccountCatalogs::CatalogTest < ActiveSupport::TestCase
  test "dispatcher resolves the catalog for each supported workspace type" do
    assert_equal AccountCatalogs::Personal, AccountCatalog.for("personal")
    assert_equal AccountCatalogs::Personal, AccountCatalog.for(:personal)
    assert_equal AccountCatalogs::Business, AccountCatalog.for("business")
    assert_equal AccountCatalogs::Business, AccountCatalog.for(:business)
  end

  test "dispatcher raises for an unsupported workspace type" do
    error = assert_raises(ArgumentError) { AccountCatalog.for(:corporate) }
    assert_equal "Unsupported workspace catalog type: corporate", error.message
  end

  test "categories exposes each category and its account types" do
    categories = AccountCatalogs::Personal.categories

    assert_equal %w[ASSET LIABILITY EQUITY INCOME EXPENSE], categories.map { |group| group[:category] }
    assert_equal [ "Cash & Liquid Assets", "Investments & Long-Term Assets" ],
                 categories.first[:account_types].map { |entry| entry[:account_type] }
    assert_equal [ "Personal Outflows" ], categories.last[:account_types].map { |entry| entry[:account_type] }
  end

  test "account_types flattens the whole chart" do
    types = AccountCatalogs::Personal.account_types

    assert_equal 7, types.length
    assert types.all? { |entry| entry[:account_type].present? && entry[:detail_types].present? }
  end

  test "detail_types_for returns the detail types of an account type" do
    catalog = AccountCatalogs::Personal

    assert_equal [ "Checking Account", "Savings Account", "Physical Cash & Digital Wallets" ],
                 catalog.detail_types_for("Cash & Liquid Assets")
    assert_nil catalog.detail_types_for("Bogus")
  end

  test "as_hash maps every account type to its category and detail types" do
    hash = AccountCatalogs::Personal.as_hash

    assert_equal({ category: "ASSET", detail_types: [ "Checking Account", "Savings Account", "Physical Cash & Digital Wallets" ] },
                 hash["Cash & Liquid Assets"])
    assert_equal hash.keys, AccountCatalogs::Personal.account_types.map { |entry| entry[:account_type] }
  end

  test "business catalog follows the same chart structure" do
    categories = AccountCatalogs::Business.categories

    assert_equal %w[ASSET LIABILITY EQUITY INCOME EXPENSE], categories.map { |group| group[:category] }
    assert_equal [ "Bank", "Accounts receivable (A/R)", "Other Current Assets", "Fixed Assets", "Other Assets" ],
                 categories.first[:account_types].map { |entry| entry[:account_type] }
  end

  test "workspace resolves its catalog by type" do
    personal = workspaces(:ada_store)
    business = workspaces(:bola_shop)
    business.update!(type: :business)

    assert_equal AccountCatalogs::Personal, personal.catalog
    assert_equal AccountCatalogs::Business, business.catalog
  end
end
