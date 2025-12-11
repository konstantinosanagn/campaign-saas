require "rails_helper"
require "faraday"

RSpec.describe GoogleOauthTokenRefresher do
  let(:user) do
    double(
      "User",
      gmail_access_token: "old_token",
      gmail_refresh_token: "refresh_token",
      gmail_token_expires_at: 10.minutes.from_now,
      update!: nil
    )
  end

  describe ".needs_refresh?" do
    it "returns false if refresh token is blank" do
      u = double(gmail_refresh_token: nil)
      expect(described_class.needs_refresh?(u)).to eq(false)
    end

    it "returns true if access token is blank" do
      u = double(gmail_refresh_token: "r", gmail_access_token: nil, gmail_token_expires_at: 1.hour.from_now)
      expect(described_class.needs_refresh?(u)).to eq(true)
    end

    it "returns true if token expires at is blank" do
      u = double(gmail_refresh_token: "r", gmail_access_token: "a", gmail_token_expires_at: nil)
      expect(described_class.needs_refresh?(u)).to eq(true)
    end

    it "returns true if token expires in less than 5 minutes" do
      u = double(gmail_refresh_token: "r", gmail_access_token: "a", gmail_token_expires_at: 4.minutes.from_now)
      expect(described_class.needs_refresh?(u)).to eq(true)
    end

    it "returns false if token expires in more than 5 minutes" do
      u = double(gmail_refresh_token: "r", gmail_access_token: "a", gmail_token_expires_at: 10.minutes.from_now)
      expect(described_class.needs_refresh?(u)).to eq(false)
    end
  end

  describe ".refresh!" do
    let(:token_response) do
      {
        "access_token" => "new_token",
        "expires_in" => 3600
      }.to_json
    end
    let(:success_response) { instance_double(Faraday::Response, status: 200, body: token_response, success?: true) }

    before do
      allow(ENV).to receive(:fetch).with("GOOGLE_CLIENT_ID").and_return("client_id")
      allow(ENV).to receive(:fetch).with("GOOGLE_CLIENT_SECRET").and_return("client_secret")
      allow(Faraday).to receive(:post).and_return(success_response)
      allow(user).to receive(:update!)
      allow(Rails.logger).to receive(:error)
    end

    it "returns user if no refresh needed" do
      allow(described_class).to receive(:needs_refresh?).with(user).and_return(false)
      expect(described_class.refresh!(user)).to eq(user)
      expect(Faraday).not_to have_received(:post)
    end

    it "refreshes token and updates user if needed" do
      allow(described_class).to receive(:needs_refresh?).with(user).and_return(true)
      expect(user).to receive(:update!).with(hash_including(gmail_access_token: "new_token"))
      expect(described_class.refresh!(user)).to eq(user)
      expect(Faraday).to have_received(:post)
    end

    context "when response is unsuccessful" do
      let(:error_response) { instance_double(Faraday::Response, status: 500, body: "Internal Server Error", success?: false) }

      before do
        allow(Faraday).to receive(:post).and_return(error_response)
      end

      it "raises generic error for non-auth errors" do
        allow(described_class).to receive(:needs_refresh?).with(user).and_return(true)
        expect {
          described_class.refresh!(user)
        }.to raise_error(RuntimeError, /Google token refresh failed/)
        expect(Rails.logger).to have_received(:error).with(/Refresh failed/)
      end

      [ 401, 403 ].each do |status|
        it "raises GmailAuthorizationError for status #{status}" do
          auth_error_response = instance_double(Faraday::Response, status: status, body: "Unauthorized", success?: false)
          allow(Faraday).to receive(:post).and_return(auth_error_response)
          allow(described_class).to receive(:needs_refresh?).with(user).and_return(true)
          expect {
            described_class.refresh!(user)
          }.to raise_error(GmailAuthorizationError)
          expect(Rails.logger).to have_received(:error).with(/Refresh failed/)
        end
      end

      it "raises GmailAuthorizationError for invalid_grant in body" do
        invalid_grant_response = instance_double(Faraday::Response, status: 400, body: "invalid_grant", success?: false)
        allow(Faraday).to receive(:post).and_return(invalid_grant_response)
        allow(described_class).to receive(:needs_refresh?).with(user).and_return(true)
        expect {
          described_class.refresh!(user)
        }.to raise_error(GmailAuthorizationError)
        expect(Rails.logger).to have_received(:error).with(/Refresh failed/)
      end
    end
  end
end
