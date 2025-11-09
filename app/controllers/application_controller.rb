class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # Development helper: Auto-set API keys for admin@example user
  before_action :set_default_api_keys_for_admin, if: -> { Rails.env.development? }

  def current_user
    user = super
    normalize_user(user)
  end

  private

  def set_default_api_keys_for_admin
    # In development, always set keys for any request
    # This ensures API keys are available even when auth is skipped

    # Don't overwrite if keys are already set by user
    return if session[:llm_api_key].present? && session[:tavily_api_key].present?

    # Set default API keys for development testing
    # These are the keys you provided
    session[:llm_api_key] = "AIzaSyCtqoCmJ9r5zxSSYu27Kxffa5HaXDrlKvE"
    session[:tavily_api_key] = "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"

    # Log for debugging
    Rails.logger.info "Auto-set API keys for development: llm=#{session[:llm_api_key].present?}, tavily=#{session[:tavily_api_key].present?}"
  end

  def normalize_user(user)
    return user if user.is_a?(User) || user.nil?

    user_id =
      if user.respond_to?(:[])
        user[:id] || user["id"]
      end

    user_id ? User.find_by(id: user_id) : user
  end
end
