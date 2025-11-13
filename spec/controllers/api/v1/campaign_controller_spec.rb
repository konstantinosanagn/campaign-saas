require "rails_helper"

RSpec.describe Api::V1::CampaignsController, type: :controller do
  let(:user) { double("User", id: 1) }

  before do
    allow_any_instance_of(Api::V1::BaseController).to receive(:skip_auth?).and_return(true)
    allow_any_instance_of(Api::V1::BaseController).to receive(:current_user).and_return(user)
  end

  describe "GET #index" do
    it "returns campaigns for current_user" do
      campaigns = [ double(id: 1), double(id: 2) ]
      allow(user).to receive_message_chain(:campaigns, :includes).and_return(campaigns)

      get :index

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.length).to eq(2)
    end
  end

  describe "POST #create" do
    let(:params) { { campaign: { title: "New" } } }

    it "creates campaign when save succeeds" do
      campaign_double = instance_double("Campaign", save: true)
      allow(user).to receive_message_chain(:campaigns, :build).and_return(campaign_double)

      post :create, params: params

      expect(response).to have_http_status(:created)
    end

    it "returns errors when save fails" do
      campaign_double = instance_double("Campaign", save: false, errors: double(full_messages: [ "bad" ]))
      allow(user).to receive_message_chain(:campaigns, :build).and_return(campaign_double)

      post :create, params: params

      expect(response).to have_http_status(:unprocessable_entity)
      body = JSON.parse(response.body)
      expect(body["errors"]).to include("bad")
    end
  end

  describe "PATCH #update" do
    let(:id) { 11 }
    let(:params) { { id: id, campaign: { title: "Updated" } } }

    it "updates when found and valid" do
      campaign = double(update: true)
      campaigns = double(find_by: campaign)
      allow(user).to receive(:campaigns).and_return(campaigns)

      patch :update, params: params

      expect(response).to have_http_status(:ok)
    end

    it "returns errors when update fails" do
      campaign = double(update: false, errors: double(full_messages: [ "err" ]))
      campaigns = double(find_by: campaign)
      allow(user).to receive(:campaigns).and_return(campaigns)

      patch :update, params: params

      expect(response).to have_http_status(:unprocessable_entity)
      body = JSON.parse(response.body)
      expect(body["errors"]).to include("err")
    end

    it "returns not found when campaign missing" do
      campaigns = double(find_by: nil)
      allow(user).to receive(:campaigns).and_return(campaigns)

      patch :update, params: params

      expect(response).to have_http_status(:unprocessable_entity)
      body = JSON.parse(response.body)
      expect(body["errors"]).to include(/Not found or unauthorized/)
    end

    it "merges sharedSettings when updating" do
      shared_settings_param = { "x" => 2 }
      existing_shared = { "y" => 1 }
      params_with_shared = { id: id, campaign: { sharedSettings: shared_settings_param } }

      campaign = double(read_attribute: existing_shared, update: true)
      campaigns = double(find_by: campaign)
      allow(user).to receive(:campaigns).and_return(campaigns)

      expect(campaign).to receive(:update).with(hash_including('shared_settings' => hash_including('x' => '2', 'y' => 1))).and_return(true)

      patch :update, params: params_with_shared

      expect(response).to have_http_status(:ok)
    end

    it "uses sharedSettings as-is when campaign not found during update" do
      shared_settings_param = { "x" => 2 }
      params_with_shared = { id: id, campaign: { sharedSettings: shared_settings_param } }

      campaigns = double(find_by: nil)
      allow(user).to receive(:campaigns).and_return(campaigns)
      # Need to allow campaigns to be called twice - once in update action, once in campaign_params
      allow(user).to receive(:campaigns).and_return(campaigns)

      patch :update, params: params_with_shared

      expect(response).to have_http_status(:unprocessable_entity)
      body = JSON.parse(response.body)
      expect(body["errors"]).to include(/Not found or unauthorized/)
    end

    it "campaign_params sets shared_settings when campaign not found but id exists" do
      shared_settings_param = { "x" => 2 }
      params_with_shared = { id: id, campaign: { sharedSettings: shared_settings_param } }

      # Mock the controller to allow accessing campaign_params
      campaigns = double(find_by: nil)
      allow(user).to receive(:campaigns).and_return(campaigns)

      # Set up params in the controller
      controller.params = ActionController::Parameters.new(params_with_shared)

      # Call campaign_params directly to test the else branch on line 87
      result = controller.send(:campaign_params)

      # Verify that shared_settings was set (line 87 executed)
      expect(result[:shared_settings]).to eq(shared_settings_param)
    end
  end

  describe "DELETE #destroy" do
    it "destroys when found" do
      campaign = double(destroy: true)
      campaigns = double(find_by: campaign)
      allow(user).to receive(:campaigns).and_return(campaigns)

      delete :destroy, params: { id: 5 }

      expect(response).to have_http_status(:no_content)
    end

    it "returns not found when missing" do
      campaigns = double(find_by: nil)
      allow(user).to receive(:campaigns).and_return(campaigns)

      delete :destroy, params: { id: 5 }

      expect(response).to have_http_status(:not_found)
      body = JSON.parse(response.body)
      expect(body["errors"]).to include(/Not found or unauthorized/).or include(/Not found/)
    end
  end

  describe "POST #send_emails" do
    let(:id) { 20 }

    it "returns not_found when campaign missing" do
      allow(user).to receive_message_chain(:campaigns, :includes, :find_by).and_return(nil)

      post :send_emails, params: { id: id }

      expect(response).to have_http_status(:not_found)
      body = JSON.parse(response.body)
      expect(body["errors"]).to include(/Campaign not found/)
    end

    it "returns success when EmailSenderService succeeds" do
      campaign = double(id: id)
      allow(user).to receive_message_chain(:campaigns, :includes, :find_by).and_return(campaign)

      result = { sent: 3, failed: 1, errors: [] }
      allow(EmailSenderService).to receive(:send_emails_for_campaign).with(campaign).and_return(result)

      post :send_emails, params: { id: id }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["success"]).to be true
      expect(body["sent"]).to eq(3)
    end

    it "handles errors raised by EmailSenderService and returns 500" do
      campaign = double(id: id)
      allow(user).to receive_message_chain(:campaigns, :includes, :find_by).and_return(campaign)

      allow(EmailSenderService).to receive(:send_emails_for_campaign).and_raise("error")

      post :send_emails, params: { id: id }

      expect(response).to have_http_status(:internal_server_error)
      body = JSON.parse(response.body)
      expect(body["success"]).to be false
      expect(body["error"]).to match(/error/)
    end
  end
end
