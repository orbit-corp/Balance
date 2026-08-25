class RegistrationsController < ApplicationController
  layout "auth"

  allow_unauthenticated_access
  skip_before_action :require_current_workspace

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    @user.save!

    start_new_session_for @user
    redirect_to onboarding_step_path(:workspace_type)
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_content
  end

  private

  def user_params
    params.permit(:full_name, :email_address, :password)
  end
end
