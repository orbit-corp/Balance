class RegistrationsController < ApplicationController
  allow_unauthenticated_access

  def new
    @user = User.new
  end

  def create
    @user = User.new(email_address: params[:email_address], password: params[:password])

    ActiveRecord::Base.transaction do
      workspace = Workspace.create!(name: params[:business_name])
      @user.workspace = workspace
      @user.save!
      Category.seed_defaults_for(workspace)
    end

    start_new_session_for @user
    redirect_to dashboard_path
  rescue ActiveRecord::RecordInvalid => invalid
    invalid.record.errors.each { |error| @user.errors.add(error.attribute, error.message) unless invalid.record == @user }
    render :new, status: :unprocessable_entity
  end
end
