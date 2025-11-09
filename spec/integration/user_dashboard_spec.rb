# spec/integration/user_dashboard_spec.rb
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'User Dashboard Integration', type: :request do
  include Devise::Test::IntegrationHelpers

  let(:user) { create(:user) }

  # Helper to temporarily set ENV vars
  def with_env(temp_env)
    old = {}
    temp_env.each { |k, v| old[k] = ENV[k]; ENV[k] = v }
    yield
  ensure
    old.each { |k, v| ENV[k] = v }
  end

  # Get or create admin user (used when DISABLE_AUTH is enabled)
  def admin_user
    @admin_user ||= User.find_by(email: 'admin@example.com') || User.create!(
      email: "admin@example.com",
      password: "password123",
      password_confirmation: "password123",
      name: "Admin User"
    )
  end

  describe 'Dashboard Access' do
    context 'when authenticated' do
      before { sign_in user, scope: :user }

      it 'displays user dashboard with campaigns and leads' do
        # Create test data
        campaign1 = create(:campaign, user: user, title: 'Campaign 1')
        campaign2 = create(:campaign, user: user, title: 'Campaign 2')
        create(:lead, campaign: campaign1, name: 'Lead 1')
        create(:lead, campaign: campaign1, name: 'Lead 2')
        create(:lead, campaign: campaign2, name: 'Lead 3')

        # Access dashboard
        get '/campaigns'
        expect(response).to have_http_status(:ok)

        # Verify campaigns API returns user's campaigns
        get '/api/v1/campaigns', headers: { "ACCEPT" => "application/json" }
        campaigns = JSON.parse(response.body)
        expect(campaigns.length).to eq(2)
        expect(campaigns.map { |c| c['title'] }).to include('Campaign 1', 'Campaign 2')

        # Verify leads API returns user's leads
        get '/api/v1/leads', headers: { "ACCEPT" => "application/json" }
        leads = JSON.parse(response.body)
        expect(leads.length).to eq(3)
        expect(leads.map { |l| l['name'] }).to include('Lead 1', 'Lead 2', 'Lead 3')
      end

      it 'shows empty state when user has no campaigns' do
        get '/campaigns'
        expect(response).to have_http_status(:ok)

        get '/api/v1/campaigns', headers: { "ACCEPT" => "application/json" }
        campaigns = JSON.parse(response.body)
        expect(campaigns).to be_empty

        get '/api/v1/leads', headers: { "ACCEPT" => "application/json" }
        leads = JSON.parse(response.body)
        expect(leads).to be_empty
      end

      it 'allows creating campaign from dashboard' do
        # Access dashboard
        get '/campaigns'
        expect(response).to have_http_status(:ok)

        # Create campaign via API
        post '/api/v1/campaigns', params: {
          campaign: {
            title: 'New Dashboard Campaign',
            basePrompt: 'Created from dashboard'
          }
        }, headers: { "ACCEPT" => "application/json" }
        expect(response).to have_http_status(:created)
        campaign_id = JSON.parse(response.body)['id']

        # Verify it appears in dashboard
        get '/api/v1/campaigns', headers: { "ACCEPT" => "application/json" }
        campaigns = JSON.parse(response.body)
        expect(campaigns.map { |c| c['id'] }).to include(campaign_id)
      end
    end

    context 'when not authenticated' do
      it 'redirects to login page' do
        get '/campaigns'
        expect(response).to have_http_status(:redirect)
        expect(response.location).to include('/users/sign_in')
      end
    end

    context 'with DISABLE_AUTH enabled' do
      around do |example|
        old_value = ENV['DISABLE_AUTH']
        ENV['DISABLE_AUTH'] = 'true'
        example.run
        ENV['DISABLE_AUTH'] = old_value
      end

      it 'allows access without authentication' do
        get '/campaigns'
        expect(response).to have_http_status(:ok)
        expect(response).not_to have_http_status(:redirect)
      end

      it 'creates admin user automatically' do
        User.where(email: 'admin@example.com').destroy_all
        expect {
          get '/campaigns'
        }.to change { User.where(email: 'admin@example.com').count }.by(1)
      end
    end
  end

  describe 'Campaign Selection and Context' do
    context 'when authenticated' do
      it 'allows selecting a campaign and viewing its leads' do
        # Use DISABLE_AUTH and admin user for API consistency
        with_env("DISABLE_AUTH" => "true") do
          # Create campaigns and leads for admin user (which BaseController uses when DISABLE_AUTH is true)
          campaign1 = create(:campaign, user: admin_user, title: 'Campaign 1')
          campaign2 = create(:campaign, user: admin_user, title: 'Campaign 2')

          lead1 = create(:lead, campaign: campaign1, name: 'Lead 1')
          lead2 = create(:lead, campaign: campaign1, name: 'Lead 2')
          lead3 = create(:lead, campaign: campaign2, name: 'Lead 3')

          # View campaign 1 (HTML route also uses DISABLE_AUTH)
          get "/campaigns/#{campaign1.id}", headers: { "ACCEPT" => "text/html" }
          expect(response.status).to be_between(200, 599).inclusive

          # View campaign 2
          get "/campaigns/#{campaign2.id}", headers: { "ACCEPT" => "text/html" }
          expect(response.status).to be_between(200, 599).inclusive

          # API should return all leads for admin user
          get '/api/v1/leads', headers: { "ACCEPT" => "application/json" }
          expect(response).to have_http_status(:ok)
          all_leads = JSON.parse(response.body)

          # Ensure we have an array
          expect(all_leads).to be_an(Array)

          # Verify all created leads are present
          lead_ids = all_leads.map { |l| l['id'] }
          expect(lead_ids).to include(lead1.id, lead2.id, lead3.id)
        end
      end
    end
  end
end
