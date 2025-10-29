# spec/integration/api_key_management_spec.rb
# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API Key Management Integration", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:user) { create(:user) }

  def json_headers
    {
      "ACCEPT" => "application/json",
      "CONTENT_TYPE" => "application/json"
    }
  end

  # Prefer PATCH for singular resources; fall back to PUT if your routes only allow PUT
  def patch_or_put(path, params: {}, headers: {})
    begin
      patch path, params: params.to_json, headers: headers
    rescue ActionController::RoutingError, AbstractController::ActionNotFound
      put path, params: params.to_json, headers: headers
    end
  end

  # Temporarily set ENV vars inside a block
  def with_env(temp_env)
    old = {}
    temp_env.each { |k, v| old[k] = ENV[k]; ENV[k] = v }
    yield
  ensure
    old.each { |k, v| ENV[k] = v }
  end

  describe "API Key Storage" do
    context "when authenticated" do
      # Option A (robust): bypass auth via DISABLE_AUTH; BaseController will use admin@example.com
      it "allows storing and retrieving API keys" do
        with_env("DISABLE_AUTH" => "true") do
          # Initially empty
          get "/api/v1/api_keys", headers: json_headers
          expect(response).to have_http_status(:ok)
          keys = JSON.parse(response.body)
          expect(keys["llmApiKey"]).to eq("")
          expect(keys["tavilyApiKey"]).to eq("")

          # Store keys
          patch_or_put "/api/v1/api_keys",
                       params: { llmApiKey: "test_llm_key_123", tavilyApiKey: "test_tavily_key_456" },
                       headers: json_headers
          expect(response).to have_http_status(:ok)
          stored = JSON.parse(response.body)
          expect(stored["llmApiKey"]).to eq("test_llm_key_123")
          expect(stored["tavilyApiKey"]).to eq("test_tavily_key_456")

          # Update again
          patch_or_put "/api/v1/api_keys",
                       params: { llmApiKey: "updated_llm_key", tavilyApiKey: "updated_tavily_key" },
                       headers: json_headers
          expect(response).to have_http_status(:ok)
          updated = JSON.parse(response.body)
          expect(updated["llmApiKey"]).to eq("updated_llm_key")
          expect(updated["tavilyApiKey"]).to eq("updated_tavily_key")
        end
      end

      it "handles nested parameters" do
        with_env("DISABLE_AUTH" => "true") do
          patch_or_put "/api/v1/api_keys",
                       params: { api_keys: { llmApiKey: "nested_llm_key", tavilyApiKey: "nested_tavily_key" } },
                       headers: json_headers
          expect(response).to have_http_status(:ok)
          data = JSON.parse(response.body)
          expect(data["llmApiKey"]).to eq("nested_llm_key")
          expect(data["tavilyApiKey"]).to eq("nested_tavily_key")
        end
      end

      it "allows clearing keys" do
        with_env("DISABLE_AUTH" => "true") do
          # Set keys first
          patch_or_put "/api/v1/api_keys",
                       params: { llmApiKey: "to_clear", tavilyApiKey: "to_clear" },
                       headers: json_headers
          expect(response).to have_http_status(:ok)

          # Clear keys
          patch_or_put "/api/v1/api_keys",
                       params: { llmApiKey: "", tavilyApiKey: "" },
                       headers: json_headers
          expect(response).to have_http_status(:ok)
          cleared = JSON.parse(response.body)
          expect(cleared["llmApiKey"]).to eq("")
          expect(cleared["tavilyApiKey"]).to eq("")
        end
      end
    end

    context "when not authenticated" do
      it "requires authentication for show and update" do
        # Ensure bypass is off
        with_env("DISABLE_AUTH" => nil) do
          get "/api/v1/api_keys", headers: json_headers
          expect(response).to have_http_status(:unauthorized)

          patch_or_put "/api/v1/api_keys",
                       params: { llmApiKey: "x", tavilyApiKey: "y" },
                       headers: json_headers
          expect(response).to have_http_status(:unauthorized)
        end
      end
    end
  end
end
