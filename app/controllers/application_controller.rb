class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  DEFAULT_DEV_LLM_KEY = "AIzaSyCtqoCmJ9r5zxSSYu27Kxffa5HaXDrlKvE"
  DEFAULT_DEV_TAVILY_KEY = "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"

  # Development helper: ensure the admin user always has default API keys
  before_action :ensure_default_api_keys_for_admin, if: -> { Rails.env.development? }

  def current_user
    user = super
    normalize_user(user)
  end

  private

  def ensure_default_api_keys_for_admin
    user = current_user
    return unless user

    updates = {}
    updates[:llm_api_key] = DEFAULT_DEV_LLM_KEY if user.llm_api_key.blank?
    updates[:tavily_api_key] = DEFAULT_DEV_TAVILY_KEY if user.tavily_api_key.blank?

    return if updates.empty?

    user.update(updates)
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
