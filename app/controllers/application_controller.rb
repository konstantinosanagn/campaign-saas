class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # Dev-only API keys for testing
  DEFAULT_DEV_LLM_KEY    = ENV.fetch("DEFAULT_DEV_LLM_KEY", "test-llm-key").freeze
  DEFAULT_DEV_TAVILY_KEY = ENV.fetch("DEFAULT_DEV_TAVILY_KEY", "test-tavily-key").freeze

  # Set default API keys in development (for testing convenience)
  before_action :ensure_default_api_keys_for_admin, if: -> { Rails.env.development? }

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

  def normalize_user(user)
    return nil if user.nil?

    # Handle warden hashes like { id: 1 } or { "id" => 1 }
    if user.respond_to?(:[]) && (user.is_a?(Hash) || user.respond_to?(:key?))
      id = begin
        user[:id] if user.respond_to?(:key?) && user.key?(:id)
      rescue
        nil
      end

      id ||= user["id"] if user.respond_to?(:key?) && user.key?("id")

      if id
        found = User.find_by(id: id)
        return found if found
      end
    end

    # For objects without id keys or non-hash objects, just return as-is
    user
  end

  def ensure_default_api_keys_for_admin
    return unless Rails.env.development?
    return unless current_user

    ensure_default_api_keys_for_dev
  end

  def ensure_default_api_keys_for_dev
    return unless Rails.env.development?
    return unless current_user

    user = current_user
    changed = false

    if user.respond_to?(:llm_api_key) && user.llm_api_key.blank?
      user.llm_api_key = DEFAULT_DEV_LLM_KEY
      changed = true
    end

    if user.respond_to?(:tavily_api_key) && user.tavily_api_key.blank?
      user.tavily_api_key = DEFAULT_DEV_TAVILY_KEY
      changed = true
    end

    user.save! if changed
  end

  # The path used after sign in
  def after_sign_in_path_for(resource)
    root_path
  end
end
