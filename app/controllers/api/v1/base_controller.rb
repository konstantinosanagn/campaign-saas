# Exception for Gmail authorization errors
require_relative "../../../exceptions/gmail_authorization_error"

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
        # Skip authentication when explicitly disabled, otherwise respect environment defaults
        disable_auth = ENV["DISABLE_AUTH"]
        return true if disable_auth == "true"
        return false if disable_auth == "false"

        # Default behaviour: skip in development for convenience
        Rails.env.development?
      end

      def current_user
        # For API controllers we avoid relying on Devise's current_user (which expects
        # a full Warden stack) and work directly with warden when available.
        #
        # 1) If auth is skipped (development helpers), always fall back to an admin user.
        # 2) Otherwise, try to read the user from warden, rescuing MissingWarden so specs
        #    and non‑middleware contexts don't blow up.
        if skip_auth?
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
          return normalize_user(admin_user)
        end

        authenticated_user = nil

        begin
          if respond_to?(:warden) && warden
            authenticated_user = warden.user
          end
        rescue Devise::MissingWarden
          authenticated_user = nil
        end

        authenticated_user = normalize_user(authenticated_user) if authenticated_user
        authenticated_user
      end

      # Force JSON format for API requests to ensure Devise returns 401 instead of redirecting
      def set_json_format
        request.format = :json if request.path.start_with?("/api/")
      end
    end
  end
end
