module Api
  module V1
    class BaseController < ApplicationController
      protect_from_forgery with: :null_session
      skip_before_action :verify_authenticity_token

      # Set request format to JSON for API requests to ensure proper handling
      before_action :set_json_format
      before_action :authenticate_user!, unless: :skip_auth?

      private

      def skip_auth?
        # Skip authentication in development (or when DISABLE_AUTH env var is set)
        Rails.env.development? || ENV["DISABLE_AUTH"] == "true"
      end

  def current_user
    # Get the authenticated user from Devise directly using warden to avoid recursion
    # warden.user accesses Devise's session directly without calling current_user
    authenticated_user = nil
    
    # Try to get user from Devise's warden (bypasses our overridden current_user)
    # This is the safest way to avoid infinite recursion
    # Use rescue to handle cases where warden is not available (e.g., in some tests)
    begin
      if respond_to?(:warden) && warden
        authenticated_user = warden.user
      end
    rescue Devise::MissingWarden
      # Warden not available, continue to fallback logic
      authenticated_user = nil
    end
    
    # Normalize the user if needed (from ApplicationController)
    authenticated_user = normalize_user(authenticated_user) if authenticated_user
    
    # If we have an authenticated user (from Devise session), use them
    # This will be the case when a user has logged in, even in development
    return authenticated_user if authenticated_user.present?
    
    # Only use admin user as fallback in development when no user is authenticated
    # This is for convenience when testing without logging in
    if skip_auth? && authenticated_user.nil?
      admin_user = User.find_by(email: "admin@example.com") || User.create!(
        email: "admin@example.com",
        password: "password123",
        password_confirmation: "password123",
        name: "Admin User",
        first_name: "Admin",
        last_name: "User",
        workspace_name: "Admin Workspace",
        job_title: "Administrator"
      )
      normalize_user(admin_user)
    else
      authenticated_user
    end
  end

      # Force JSON format for API requests to ensure Devise returns 401 instead of redirecting
      def set_json_format
        request.format = :json if request.path.start_with?("/api/")
      end
    end
  end
end
