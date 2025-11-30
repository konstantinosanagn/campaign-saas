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
    # Skip authentication when explicitly disabled, otherwise respect environment defaults
    disable_auth = ENV["DISABLE_AUTH"]
    return true if disable_auth == "true"
    return false if disable_auth == "false"

    # Default behaviour: skip in development for convenience
    Rails.env.development?
  end

  def current_user
    # Use ApplicationController's current_user method, which properly handles Devise authentication
    # Only override for the admin fallback in development when auth is disabled
    authenticated_user = super

    # Only use admin user as fallback in development when no user is authenticated and auth is disabled
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
      end

      admin_user = ensure_admin_profile!(admin_user)
      normalize_user(admin_user)
    else
      authenticated_user
    end
  end

  def ensure_admin_profile!(user)
    return user unless user&.email == "admin@example.com"

    # Always base updates on the persisted record to avoid stale in-memory data
    # (e.g., when tests change columns directly with `update_columns`).
    persisted_user = User.find_by(id: user.id)
    return user unless persisted_user

    updates = {}
    updates[:first_name] = "Admin" if persisted_user.first_name.blank?
    updates[:last_name] = "User" if persisted_user.last_name.blank?
    updates[:workspace_name] = "Admin Workspace" if persisted_user.workspace_name.blank?
    updates[:job_title] = "Administrator" if persisted_user.job_title.blank?

    persisted_user.update!(updates) if updates.present?
    persisted_user
  end
end
