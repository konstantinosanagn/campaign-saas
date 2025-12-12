class Users::RegistrationsController < Devise::RegistrationsController
  # Handle authentication check before Devise's require_no_authentication
  prepend_before_action :check_authentication_and_remember_me, only: [ :new ]

  # POST /resource
  def create
    build_resource(sign_up_params)

    # Combine first_name and last_name into name if provided
    if params[:first_name].present? && params[:last_name].present?
      resource.name = "#{params[:first_name]} #{params[:last_name]}".strip
    end

    # Set additional fields
    resource.first_name = params[:first_name] if params[:first_name].present?
    resource.last_name = params[:last_name] if params[:last_name].present?
    resource.workspace_name = params[:workspace_name] if params[:workspace_name].present?
    resource.job_title = params[:job_title] if params[:job_title].present?

    resource.save
    yield resource if block_given?
    if resource.persisted?
      if resource.active_for_authentication?
        set_flash_message! :notice, :signed_up
        sign_up(resource_name, resource)
        respond_with resource, location: after_sign_up_path_for(resource)
      else
        set_flash_message! :notice, :"signed_up_but_#{resource.inactive_message}"
        expire_data_after_sign_in!
        respond_with resource, location: after_inactive_sign_up_path_for(resource)
      end
    else
      clean_up_passwords resource
      set_minimum_password_length
      respond_with resource
    end
  end



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

        # Redirect to signup page to ensure clean page load
        redirect_to "/signup" and return
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

  def sign_up_params
    params.require(:user).permit(:email, :password, :password_confirmation, :name)
  end

  protected

  # The path used after sign up
  def after_sign_up_path_for(resource)
    root_path
  end

  # The path used after sign up for inactive accounts
  def after_inactive_sign_up_path_for(resource)
    root_path
  end
end
