class CampaignsController < ApplicationController
  before_action :authenticate_user!, unless: :skip_auth?

  def index
    @campaigns = current_user.campaigns
    @leads = Lead.joins(:campaign).where(campaigns: { user_id: current_user.id })
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
    if skip_auth?
      # Always use admin@example.com in development mode for testing
      admin_user = User.find_by(email: "admin@example.com") || User.create!(
        email: "admin@example.com",
        password: "password123",
        password_confirmation: "password123",
        name: "Admin User"
      )
      admin_user
    else
      super
    end
  end
end
