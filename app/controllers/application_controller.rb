class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

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
    return user if user.is_a?(User) || user.nil?
    return nil unless user.respond_to?(:[])

    user_id = user[:id] || user["id"]
    return nil if user_id.blank?

    User.find_by(id: user_id) || nil
  end

  # The path used after sign in
  def after_sign_in_path_for(resource)
    root_path
  end
end
