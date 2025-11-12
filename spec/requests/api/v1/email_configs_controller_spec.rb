require "rails_helper"
require "devise"

RSpec.describe "Api::V1::EmailConfigsController", type: :request do
  let(:user) { create(:user, email: "user@example.com", send_from_email: nil) }

  before do
    sign_in user
  end

  describe "GET /api/v1/email_config" do
    context "when current user has OAuth configured" do
      before do
        allow(GmailOauthService).to receive(:oauth_configured?).with(user).and_return(true)
        get "/api/v1/email_config"
      end

      it "returns user's email and oauth_configured true" do
        json = JSON.parse(response.body)
        expect(response).to have_http_status(:ok)
        expect(json["email"]).to eq("user@example.com")
        expect(json["oauth_configured"]).to eq(true)
      end
    end

    context "when current user does not have OAuth but send_from_email user does" do
      let(:other_user) { create(:user, email: "other@example.com") }

      before do
        user.update(send_from_email: "other@example.com")
        allow(GmailOauthService).to receive(:oauth_configured?).with(user).and_return(false)
        allow(User).to receive(:find_by).with(email: "other@example.com").and_return(other_user)
        allow(GmailOauthService).to receive(:oauth_configured?).with(other_user).and_return(true)
        allow(Rails.logger).to receive(:info)
        get "/api/v1/email_config"
      end

      it "uses OAuth from send_from_email user" do
        json = JSON.parse(response.body)
        expect(json["email"]).to eq("other@example.com")
        expect(json["oauth_configured"]).to eq(true)
        expect(Rails.logger).to have_received(:info).with(/Using OAuth/)
      end
    end

    context "when GmailOauthService raises an error" do
      before do
        allow(GmailOauthService).to receive(:oauth_configured?).and_raise(StandardError, "OAuth error")
        allow(Rails.logger).to receive(:warn)
        get "/api/v1/email_config"
      end

      it "logs warning and returns oauth_configured false" do
        json = JSON.parse(response.body)
        expect(json["oauth_configured"]).to eq(false)
        expect(Rails.logger).to have_received(:warn).with(/OAuth error/)
      end
    end
  end

  describe "PUT /api/v1/email_config" do
    context "with valid email" do
      before do
        allow(GmailOauthService).to receive(:oauth_configured?).with(user).and_return(true)
        put "/api/v1/email_config", params: { email: "new@example.com" }
      end

      it "updates send_from_email and returns JSON" do
        json = JSON.parse(response.body)
        expect(response).to have_http_status(:ok)
        expect(json["email"]).to eq("new@example.com")
        expect(json["oauth_configured"]).to eq(true)
        expect(user.reload.send_from_email).to eq("new@example.com")
      end
    end

    context "when update fails" do
      before do
        allow(user).to receive(:update).and_return(false)
        allow(user).to receive_message_chain(:errors, :full_messages).and_return([ "Invalid email" ])
        put "/api/v1/email_config", params: { email: "bademail" }
      end

      it "returns 422 with error message" do
        json = JSON.parse(response.body)
        expect(response).to have_http_status(:unprocessable_entity)
        expect(json["error"]).to eq("Invalid email")
      end
    end

    context "when email param is missing" do
      before { put "/api/v1/email_config", params: {} }

      it "returns 422 with Email is required" do
        json = JSON.parse(response.body)
        expect(response).to have_http_status(:unprocessable_entity)
        expect(json["error"]).to eq("Email is required")
      end
    end

    context "when GmailOauthService raises an error during update" do
      before do
        allow(GmailOauthService).to receive(:oauth_configured?).and_raise(StandardError, "OAuth failure")
        allow(Rails.logger).to receive(:warn)
        put "/api/v1/email_config", params: { email: "new@example.com" }
      end

      it "logs warning and returns oauth_configured false" do
        json = JSON.parse(response.body)
        expect(json["oauth_configured"]).to eq(false)
        expect(Rails.logger).to have_received(:warn).with(/OAuth failure/)
      end
    end
  end
end
