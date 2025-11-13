class CampaignsController < ApplicationController
  before_action :authenticate_user!, unless: :skip_auth?

  def index
    @campaigns = current_user.campaigns
    @leads = Lead.joins(:campaign).where(campaigns: { user_id: current_user.id })
    @user = current_user
  end

  def show
    @campaign = current_user.campaigns.find(params[:id])
    @leads = @campaign.leads
  end

  private

  def skip_auth?
    # Skip authentication in development (or when DISABLE_AUTH env var is set)
    Rails.env.development? || ENV["DISABLE_AUTH"] == "true"
  end

  def current_user
    # Get the authenticated user from Devise directly using warden to avoid recursion
    # warden.user accesses Devise's session directly without calling current_user
    authenticated_user = nil
    
    # Try to get user from Devise's warden (bypasses our overridden current_user)
    # This is the safest way to avoid infinite recursion
    if respond_to?(:warden) && warden
      authenticated_user = warden.user
    end
    
    # Normalize the user if needed (from ApplicationController)
    authenticated_user = normalize_user(authenticated_user) if authenticated_user
    
    # If we have an authenticated user (from Devise session), use them
    # This will be the case when a user has logged in, even in development
    return authenticated_user if authenticated_user.present?
    
    # Only use admin user as fallback in development when no user is authenticated
    # This is for convenience when testing without logging in
    if skip_auth? && authenticated_user.nil?
      # Always use admin@example.com in development mode for testing
      admin_user = User.find_by(email: "admin@example.com")
      
      if admin_user.nil?
        admin_user = User.create!(
          email: "admin@example.com",
          password: "password123",
          password_confirmation: "password123",
          name: "Admin User",
          first_name: "Admin",
          last_name: "User",
          workspace_name: "Admin Workspace",
          job_title: "Administrator"
        )
      else
        # Update existing admin user to ensure it has the new fields
        admin_user.update!(
          first_name: "Admin",
          last_name: "User",
          workspace_name: "Admin Workspace",
          job_title: "Administrator"
        ) if admin_user.first_name.blank? || admin_user.workspace_name.blank?
      end
      
      normalize_user(admin_user)
    else
      authenticated_user
    end
  end
end
