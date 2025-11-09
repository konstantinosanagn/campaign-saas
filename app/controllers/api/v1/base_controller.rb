module Api
  module V1
    class BaseController < ApplicationController
      protect_from_forgery with: :null_session

      before_action :authenticate_user!, unless: :skip_auth?

      private

      def skip_auth?
        # Skip authentication in development (or when DISABLE_AUTH env var is set)
        Rails.env.development? || ENV["DISABLE_AUTH"] == "true"
      end

      def current_user
        if skip_auth?
          # Always use admin@example.com in development mode for testing
          admin_user = User.find_by(email: "admin@example.com") || User.create!(
            email: "admin@example.com",
            password: "password123",
            password_confirmation: "password123",
            name: "Admin User"
          )
          admin_user
        else
          super
        end
      end
    end
  end
end
