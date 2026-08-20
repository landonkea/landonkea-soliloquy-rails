# ───────────────────────────────────────────────────────────────────
# RegistrationsController, lets someone create the (one) account this journal needs
# ───────────────────────────────────────────────────────────────────
# `bin/rails generate authentication` scaffolds login/logout and password reset, but
# not sign-up -- it assumes accounts get created some other way (an admin console, a
# seed file). This app is meant to be self-service the moment someone clones it and
# runs it, so this controller adds the one missing piece: a real registration form.
class RegistrationsController < ApplicationController
  # A brand new visitor has no session yet, so the normal "must be logged in" gate
  # (Authentication#require_authentication, included by every controller by default)
  # has to be turned off for exactly these two actions.
  allow_unauthenticated_access

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    if @user.save
      # Sign the brand new user straight in rather than making them log in again
      # immediately after registering -- start_new_session_for comes from the same
      # Authentication concern SessionsController#create uses, so a freshly
      # registered account behaves exactly like a freshly logged-in one.
      start_new_session_for @user
      redirect_to root_path, notice: "Welcome to Soliloquy."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.expect(user: [ :email_address, :password, :password_confirmation ])
  end
end
