class CustomersController < ApplicationController
  before_action :set_customer, only: %i[edit update destroy]

  def index
    @customers = current_workspace.customers.order(:name)
  end

  def new
    @customer = current_workspace.customers.build
  end

  def create
    @customer = current_workspace.customers.build(customer_params)

    if @customer.save
      redirect_out_of_frame customers_path, notice: "Customer added."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @customer.update(customer_params)
      redirect_out_of_frame customers_path, notice: "Customer updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @customer.destroy
    redirect_to customers_path, notice: "Customer deleted."
  end

  private
    def set_customer
      @customer = current_workspace.customers.find(params[:id])
    end

    def customer_params
      params.expect(customer: [ :name, :phone ])
    end
end
