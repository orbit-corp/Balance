require "test_helper"

class CustomersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:ada_store)
    @user = users(:one)
    sign_in_as(@user)
  end

  test "cannot view another workspace's customer" do
    other_workspace = workspaces(:bola_shop)
    other_customer = other_workspace.customers.create!(name: "Zainab")

    get edit_customer_path(other_customer)
    assert_response :not_found
  end

  test "cannot delete another workspace's customer" do
    other_workspace = workspaces(:bola_shop)
    other_customer = other_workspace.customers.create!(name: "Zainab")

    assert_no_difference "Customer.count" do
      delete customer_path(other_customer)
    end
    assert_response :not_found
  end
end
