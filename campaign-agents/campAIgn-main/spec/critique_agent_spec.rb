require "spec_helper"
require "webmock/rspec"
require_relative "../app/services/critique_agent"

RSpec.describe CritiqueAgent do
  let(:api_key) { "fake_api_key" }
  let(:model) { "gemini-2.5-flash" }

  let(:spam_classifier) { instance_double("SpamClassifierWrapper") }

  let(:article) do
    {
      "email_content" => "Test marketing email",
      "number_of_revisions" => 0
    }
  end

  let(:agent) do
    described_class.new(api_key: api_key, model: model).tap do |a|
      a.instance_variable_set(:@spam_classifier, spam_classifier)
    end
  end

  before do
    allow(Date).to receive(:today).and_return(Date.new(2025, 10, 28))
  end

  shared_examples "critique returns expected result" do |spam_score:, response_text:, expected_critique:|
    before do
      allow(spam_classifier).to receive(:classify).and_return(spam_score)
      stub_request(:post, /generativelanguage.googleapis.com/).to_return(
        status: 200,
        body: {
          "candidates" => [
            { "content" => { "parts" => [{ "text" => response_text }] } }
          ]
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
    end

    it "returns the expected critique" do
      result = agent.critique(article)
      expect(result["critique"]).to eq(expected_critique)
    end
  end

  describe "#critique" do
    context "non-spam email (spam_score <= 0.15)" do
      it_behaves_like "critique returns expected result",
        spam_score: 0.1,
        response_text: "Good email, minor improvements suggested.",
        expected_critique: "Good email, minor improvements suggested."
    end

    context "spam email (spam_score > 0.15)" do
      it_behaves_like "critique returns expected result",
        spam_score: 0.5,
        response_text: "Email has high spam likelihood, please fix.",
        expected_critique: "Email has high spam likelihood, please fix."
    end

    context "spam classifier raises an error" do
      it "logs a warning and continues" do
        allow(spam_classifier).to receive(:classify).and_raise(StandardError, "classifier fail")
        stub_request(:post, /generativelanguage.googleapis.com/).to_return(
          status: 200,
          body: {
            "candidates" => [
              { "content" => { "parts" => [{ "text" => "Looks fine." }] } }
            ]
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
        expect { agent.critique(article) }.to output(/Spam classifier error/).to_stderr
      end
    end

    context "network/API error occurs" do
      it "returns error hash and logs warning" do
        allow(spam_classifier).to receive(:classify).and_return(0.1)
        stub_request(:post, /generativelanguage.googleapis.com/).to_raise(SocketError, "network fail")
        expect { 
          result = agent.critique(article)
          expect(result["error"]).to eq("Network error")
        }.to output(/CritiqueAgent network error/).to_stderr
      end
    end

    context "email_content is missing" do
      let(:article) { { "number_of_revisions" => 0 } }

      it_behaves_like "critique returns expected result",
        spam_score: 0.1,
        response_text: "Default critique.",
        expected_critique: "Default critique."
    end

    context "response text is 'None'" do
      it_behaves_like "critique returns expected result",
        spam_score: 0.1,
        response_text: "None",
        expected_critique: nil
    end

    context "response text is empty" do
      it_behaves_like "critique returns expected result",
        spam_score: 0.1,
        response_text: "",
        expected_critique: nil
    end

    context "number_of_revisions is 1" do
      let(:article) { { "email_content" => "Test", "number_of_revisions" => 1 } }

      it_behaves_like "critique returns expected result",
        spam_score: 0.1,
        response_text: "Should not provide further critique",
        expected_critique: nil
    end

    context "number_of_revisions is string 1" do
      let(:article) { { "email_content" => "Test", "number_of_revisions" => "1" } }

      it_behaves_like "critique returns expected result",
        spam_score: 0.1,
        response_text: "Should not provide further critique",
        expected_critique: nil
    end

    context "number_of_revisions is not 1" do
      let(:article) { { "email_content" => "Test", "number_of_revisions" => "0" } }

      it_behaves_like "critique returns expected result",
        spam_score: 0.1,
        response_text: "Should not provide further critique",
        expected_critique: "Should not provide further critique"
    end
  end

  describe "#run" do
    it "merges the critique into the article hash" do
      allow(agent).to receive(:critique).and_return({ "critique" => "Fix text." })
      result = agent.run(article)
      expect(result["critique"]).to eq("Fix text.")
      expect(result["email_content"]).to eq("Test marketing email")
    end
  end
end
