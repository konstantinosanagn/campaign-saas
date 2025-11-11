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
        if skip_auth?
          admin_user = User.find_by(email: "admin@example.com") || User.create!(
            email: "admin@example.com",
            password: "password123",
            password_confirmation: "password123",
            name: "Admin User"
          )
          normalize_user(admin_user)
        else
          super
        end
      end

      # Force JSON format for API requests to ensure Devise returns 401 instead of redirecting
      def set_json_format
        request.format = :json if request.path.start_with?('/api/')
      end
    end
  end
end
