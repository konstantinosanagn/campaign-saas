require "rails_helper"
require "faraday"

RSpec.describe GmailSender do
  let(:user) do
    double(
      "User",
      id: 1,
      gmail_email: "sender@example.com",
      gmail_access_token: "valid_token"
    )
  end

  let(:to) { "recipient@example.com" }
  let(:subject_text) { "Test Subject" }
  let(:text_body) { "Plain text body" }
  let(:html_body) { "<p>HTML body</p>" }

  describe ".send_email" do
    it "sends correct headers and body to Faraday.post" do
      req = Struct.new(:headers, :body).new({}, nil)
      expect(Faraday).to receive(:post) do |url, &block|
        expect(url).to eq(GmailSender::GMAIL_SEND_ENDPOINT)
        block.call(req)
        expect(req.headers).to include(
          "Authorization" => "Bearer valid_token",
          "Content-Type" => "application/json"
        )
        expect(req.body).to eq({ raw: encoded_message }.to_json)
        gmail_response
      end
      GmailSender.send_email(
        user: user,
        to: to,
        subject: subject_text,
        text_body: text_body,
        html_body: html_body
      )
    end
    let(:raw_message) { "raw email message" }
    let(:encoded_message) { Base64.urlsafe_encode64(raw_message) }
    let(:gmail_response) do
      instance_double(Faraday::Response, status: 200, body: { id: "msgid", threadId: "threadid" }.to_json, success?: true)
    end

    before do
      allow(GoogleOauthTokenRefresher).to receive(:refresh!).with(user)
      allow(GmailSender).to receive(:build_raw_message).and_return(raw_message)
      allow(Base64).to receive(:urlsafe_encode64).with(raw_message).and_return(encoded_message)
      allow(Faraday).to receive(:post).and_return(gmail_response)
      allow(Rails.logger).to receive(:info)
      allow(Rails.logger).to receive(:error)
    end

    it "sends an email successfully and returns Gmail message resource" do
      result = GmailSender.send_email(
        user: user,
        to: to,
        subject: subject_text,
        text_body: text_body,
        html_body: html_body
      )
      expect(result).to include("id" => "msgid", "threadId" => "threadid")
      expect(GoogleOauthTokenRefresher).to have_received(:refresh!).with(user)
      expect(GmailSender).to have_received(:build_raw_message)
      expect(Faraday).to have_received(:post)
      expect(Rails.logger).to have_received(:info).at_least(:once)
    end

    context "when Gmail API returns an error" do
      let(:error_response) { instance_double(Faraday::Response, status: 500, body: "Internal Server Error", success?: false) }

      before do
        allow(Faraday).to receive(:post).and_return(error_response)
      end

      it "raises a generic error for non-auth errors" do
        expect {
          GmailSender.send_email(
            user: user,
            to: to,
            subject: subject_text,
            text_body: text_body
          )
        }.to raise_error(RuntimeError, /Gmail send failed/)
        expect(Rails.logger).to have_received(:error).with(/Send failed/)
      end

      [ 401, 403 ].each do |status|
        it "raises GmailAuthorizationError for status #{status}" do
          auth_error_response = instance_double(Faraday::Response, status: status, body: "Unauthorized", success?: false)
          allow(Faraday).to receive(:post).and_return(auth_error_response)
          expect {
            GmailSender.send_email(
              user: user,
              to: to,
              subject: subject_text,
              text_body: text_body
            )
          }.to raise_error(GmailAuthorizationError)
          expect(Rails.logger).to have_received(:error).with(/Send failed/)
        end
      end
    end
  end

  describe ".build_raw_message" do
    it "builds a multipart message when html_body is present" do
      message = GmailSender.build_raw_message(
        from: "sender@example.com",
        to: "recipient@example.com",
        subject: "Subject",
        text_body: "Text",
        html_body: "<p>HTML</p>"
      )
      expect(message).to include("Content-Type: multipart/alternative;")
      expect(message).to include("Content-Type: text/plain;")
      expect(message).to include("Content-Type: text/html;")
      expect(message).to include("<p>HTML</p>")
    end

    it "builds a plain text message when html_body is nil" do
      message = GmailSender.build_raw_message(
        from: "sender@example.com",
        to: "recipient@example.com",
        subject: "Subject",
        text_body: "Text",
        html_body: nil
      )
      expect(message).to include("Content-Type: text/plain;")
      expect(message).not_to include("multipart/alternative")
      expect(message).to include("Text")
    end
  end
end
