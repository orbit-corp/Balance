class RegistrationsController < ApplicationController
  layout "auth"

  allow_unauthenticated_access

  def new
    @user = User.new
  end

  def create
    @user = User.new(email_address: params[:email_address], password: params[:password])

    ActiveRecord::Base.transaction do
      workspace = Workspace.create!(name: params[:business_name])
      Account::SEED_ON_CREATE.each { |role| Account.for_role!(workspace, role) }
      @user.workspace = workspace
      @user.save!
    end

    start_new_session_for @user
    redirect_to dashboard_path
  rescue ActiveRecord::RecordInvalid => invalid
    invalid.record.errors.each { |error| @user.errors.add(error.attribute, error.message) unless invalid.record == @user }
    render :new, status: :unprocessable_content
  end
end
