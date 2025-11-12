##
# OauthController
#
# Handles OAuth callbacks for Gmail/Google Workspace email authentication
#
class OauthController < ApplicationController
  before_action :authenticate_user!

  ##
  # GET /oauth/gmail/authorize
  # Initiates OAuth flow by redirecting to Google authorization
  def gmail_authorize
    begin
      # Check if OAuth is configured
      unless ENV["GMAIL_CLIENT_ID"].present? && ENV["GMAIL_CLIENT_SECRET"].present?
        flash[:error] = "Gmail OAuth is not configured. Please set GMAIL_CLIENT_ID and GMAIL_CLIENT_SECRET environment variables."
        Rails.logger.error("Gmail OAuth not configured: missing GMAIL_CLIENT_ID or GMAIL_CLIENT_SECRET")
        redirect_to root_path
        return
      end

      Rails.logger.info("[Gmail OAuth] Starting authorization for user #{current_user.id} (#{current_user.email})")
      authorization_url = GmailOauthService.authorization_url(current_user)

      # Store state in session for security
      session[:oauth_state] = SecureRandom.hex(16)
      session[:oauth_user_id] = current_user.id  # Store user ID to verify on callback

      Rails.logger.info("[Gmail OAuth] Redirecting to: #{authorization_url}")
      redirect_to authorization_url, allow_other_host: true
    rescue => e
      error_message = "Gmail OAuth error: #{e.message}"
      flash[:error] = error_message
      Rails.logger.error("[Gmail OAuth] Authorization error: #{e.class.name} - #{e.message}")
      Rails.logger.error(e.backtrace.join("\n")) if e.backtrace
      redirect_to root_path
    end
  end

  ##
  # GET /oauth/gmail/callback
  # Handles OAuth callback from Google
  def gmail_callback
    Rails.logger.info("[Gmail OAuth] Callback received for user #{current_user.id} (#{current_user.email})")

    if params[:error].present?
      error_msg = "OAuth authorization failed: #{params[:error]}"
      Rails.logger.error("[Gmail OAuth] Callback error: #{error_msg}")
      flash[:error] = error_msg
      redirect_to root_path
      return
    end

    code = params[:code]
    unless code.present?
      Rails.logger.error("[Gmail OAuth] No authorization code received")
      flash[:error] = "No authorization code received"
      redirect_to root_path
      return
    end

    # Verify user ID matches (security check)
    if session[:oauth_user_id].present? && session[:oauth_user_id] != current_user.id
      Rails.logger.warn("[Gmail OAuth] User ID mismatch: session=#{session[:oauth_user_id]}, current=#{current_user.id}")
    end

    begin
      Rails.logger.info("[Gmail OAuth] Exchanging code for tokens for user #{current_user.id}")
      if GmailOauthService.exchange_code_for_tokens(current_user, code)
        Rails.logger.info("[Gmail OAuth] Successfully configured for user #{current_user.id} (#{current_user.email})")
        # Clear session
        session.delete(:oauth_state)
        session.delete(:oauth_user_id)
        flash[:success] = "Gmail OAuth successfully configured! You can now send emails."
      else
        Rails.logger.error("[Gmail OAuth] Failed to exchange code for tokens for user #{current_user.id}")
        flash[:error] = "Failed to configure Gmail OAuth. Please try again."
      end
    rescue => e
      Rails.logger.error("[Gmail OAuth] Callback exception: #{e.class} #{e.message}")
      Rails.logger.error(e.backtrace.join("\n")) if e.backtrace
      flash[:error] = "OAuth callback failed: #{e.message}"
    end

    redirect_to root_path
  end

  ##
  # DELETE /oauth/gmail/revoke
  # Revokes OAuth tokens
  def gmail_revoke
    current_user.update!(
      gmail_access_token: nil,
      gmail_refresh_token: nil,
      gmail_token_expires_at: nil
    )

    flash[:success] = "Gmail OAuth revoked successfully."
    redirect_to root_path
  end
end
