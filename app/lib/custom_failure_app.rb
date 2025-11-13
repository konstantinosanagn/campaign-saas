# Custom failure app for Devise to redirect to custom routes in production
class CustomFailureApp < Devise::FailureApp
  def redirect_url
    if Rails.env.production?
      # Use custom routes in production
      if warden_options[:scope] == :user
        # Check if the request was for signup
        if request.path == '/users/sign_up' || request.path == '/signup' || 
           request.referer&.include?('/signup') || request.referer&.include?('/users/sign_up')
          '/signup'
        else
          '/login'
        end
      else
        super
      end
    else
      # Use default Devise routes in development
      super
    end
  end
end

