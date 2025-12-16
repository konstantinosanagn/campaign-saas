module Admin
  class BaseController < ApplicationController
    before_action :authenticate_user!
    before_action :require_admin!

    private

    def require_admin!
      emails = ENV.fetch("ADMIN_EMAILS", "")
                 .split(",")
                 .map(&:strip)
                 .reject(&:empty?)

      # Prefer 404 to avoid advertising admin surface area.
      head :not_found and return unless emails.include?(current_user.email.to_s)
    end
  end
end
