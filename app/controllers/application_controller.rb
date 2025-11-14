class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  DEFAULT_DEV_LLM_KEY = "AIzaSyCtqoCmJ9r5zxSSYu27Kxffa5HaXDrlKvE"
  DEFAULT_DEV_TAVILY_KEY = "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"

  # Development helper: ensure users have default API keys in development
  before_action :ensure_default_api_keys_for_dev, if: -> { Rails.env.development? }

  # Override Devise path helpers to use custom routes in production
  def new_user_session_path(*args)
    if Rails.env.production?
      "/login"
    else
      # In development, use Devise's default path
      Rails.application.routes.url_helpers.new_user_session_path(*args)
    end
  end

  def new_user_registration_path(*args)
    if Rails.env.production?
      "/signup"
    else
      # In development, use Devise's default path
      Rails.application.routes.url_helpers.new_user_registration_path(*args)
    end
  end

  def current_user
    user = super
    normalize_user(user)
  end

  private

  def ensure_default_api_keys_for_dev
    # Double-check we're in development mode (safety check)
    return unless Rails.env.development?

    user = current_user
    return unless user

    # In development, give all users default API keys for convenience
    # This should NEVER run in production
    updates = {}
    updates[:llm_api_key] = DEFAULT_DEV_LLM_KEY if user.llm_api_key.blank?
    updates[:tavily_api_key] = DEFAULT_DEV_TAVILY_KEY if user.tavily_api_key.blank?

    return if updates.empty?

    user.update(updates)
  end

  def normalize_user(user)
    return user if user.is_a?(User) || user.nil?
    return user unless user.respond_to?(:[])

    user_id = user[:id] || user["id"]
    return user if user_id.blank?

    User.find_by(id: user_id) || user
  end
end
