class Users::SessionsController < Devise::SessionsController
  # Handle authentication check before Devise's require_no_authentication
  prepend_before_action :check_authentication_and_remember_me, only: [ :new ]

  # Store remember_me state for use in after_action
  attr_accessor :remember_me_was_checked

  # Override create to ensure remember_me is properly handled
  def create
    # Check if remember_me is actually checked (it will be "1" if checked, absent or "0" if not)
    self.remember_me_was_checked = params[:user] && params[:user][:remember_me] == "1"

    # Before processing login, if remember_me is not checked, clear any existing cookie
    unless remember_me_was_checked
      cookie_name = "remember_user_token"
      cookies.delete(cookie_name, domain: :all)
      cookies.delete(cookie_name)
    end

    # Temporarily remove remember_me from params if not checked to prevent Devise from setting it
    original_remember_me = nil
    if params[:user] && !remember_me_was_checked
      original_remember_me = params[:user].delete(:remember_me)
    end

    super

    # After successful login, if remember_me was not checked, ensure everything is cleared
    if user_signed_in? && !remember_me_was_checked
      # Clear the database field to ensure state is consistent
      if current_user.remember_created_at.present?
        current_user.update_column(:remember_created_at, nil)
      end
      # Also ensure cookie is cleared (in case Devise set it somehow)
      cookie_name = "remember_user_token"
      cookies.delete(cookie_name, domain: :all)
      cookies.delete(cookie_name)
    end

    # Restore the param if we removed it (for potential error handling)
    if original_remember_me && params[:user]
      params[:user][:remember_me] = original_remember_me
    end
  end

  # Clean up remember_me after sign in if it wasn't checked
  after_action :cleanup_remember_me_if_not_checked, only: [:create]

  def cleanup_remember_me_if_not_checked
    return unless user_signed_in? && !remember_me_was_checked

    # Clear the database field
    if current_user.remember_created_at.present?
      current_user.update_column(:remember_created_at, nil)
    end
    # Clear the cookie
    cookie_name = "remember_user_token"
    cookies.delete(cookie_name, domain: :all)
    cookies.delete(cookie_name)
  end

  # Override destroy (sign out) to ensure remember_me is cleared
  def destroy
    # Get the user before signing out
    user = current_user

    super

    # After sign out, explicitly clear remember_me cookie and database field
    if user
      cookie_name = "remember_user_token"
      cookies.delete(cookie_name, domain: :all)
      cookies.delete(cookie_name)

      # Clear the database field
      if user.remember_created_at.present?
        user.update_column(:remember_created_at, nil)
      end
    end
  end

  private

  def check_authentication_and_remember_me
    # If user is authenticated, check if they have "remember me" set
    if user_signed_in?
      # Check if user is remembered via cookie (remember_me functionality)
      if user_remembered?
        # If remembered, redirect to user page
        redirect_to root_path and return
      else
        # If not remembered, sign them out and clear remember_me cookie
        # Explicitly clear the remember_me cookie to ensure it's removed
        cookie_name = "remember_user_token"
        cookies.delete(cookie_name, domain: :all)
        cookies.delete(cookie_name)

        # Clear the remember_created_at in the database
        current_user.update_column(:remember_created_at, nil) if current_user.remember_created_at.present?

        # Sign out the user
        sign_out(:user)

        # Clear any flash messages about being already signed in
        flash.delete(:alert)

        # Redirect to login page to ensure clean page load
        redirect_to "/login" and return
      end
    end
  end

  # Check if user is remembered via Devise's remember_me cookie
  def user_remembered?
    return false unless user_signed_in?

    # Check both the cookie and the database field to ensure they're actually remembered
    cookie_name = "remember_user_token"
    has_cookie = cookies.signed[cookie_name].present? ||
                 cookies.encrypted[cookie_name].present? ||
                 cookies[cookie_name].present?

    # Also check if the user has remember_created_at set in the database
    # This ensures the remember_me state is actually active (Devise handles expiration)
    has_db_remember = current_user.remember_created_at.present?

    has_cookie && has_db_remember
  end

  protected

  # The path used after sign in (delegates to ApplicationController)
  def after_sign_in_path_for(resource)
    # Cleanup is handled in after_action callback
    super
  end

  # The path used after sign out
  def after_sign_out_path_for(resource_or_scope)
    "/login"
  end
end
