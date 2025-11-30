class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def google_oauth2
    auth = request.env["omniauth.auth"]

    @user = User.from_google_omniauth(auth)

    if @user.persisted?
      credentials = auth.credentials

      # Store Gmail-related tokens and email
      @user.update!(
        gmail_access_token:  credentials.token,
        # refresh_token may be nil on subsequent logins; only overwrite if present
        gmail_refresh_token: credentials.refresh_token.presence || @user.gmail_refresh_token,
        gmail_token_expires_at: (Time.at(credentials.expires_at) if credentials.expires_at),
        gmail_email: auth.info.email
      )

      sign_in(@user, event: :authentication)

      if @user.profile_complete?
        # Existing user with full profile → go to dashboard
        redirect_to after_sign_in_path_for(@user)
      else
        # New or incomplete profile → show signup/onboarding card
        redirect_to complete_profile_path
      end
    else
      session["devise.google_data"] = auth.except("extra")
      redirect_to new_user_registration_url,
                  alert: "There was a problem signing you in through Google. Please register or try again."
    end
  end

  def failure
    redirect_to new_user_session_path, alert: "Authentication failed. Please try again."
  end
end
