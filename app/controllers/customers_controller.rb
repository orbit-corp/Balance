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
      redirect_to customers_path
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @customer.update(customer_params)
      redirect_to customers_path
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @customer.destroy
    redirect_to customers_path
  end

  private
    def set_customer
      @customer = current_workspace.customers.find(params[:id])
    end

    def customer_params
      params.require(:customer).permit(:name, :phone)
    end
end
