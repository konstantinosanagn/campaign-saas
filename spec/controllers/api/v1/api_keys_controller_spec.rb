require "rails_helper"

RSpec.describe Api::V1::ApiKeysController, type: :controller do
  before do
    allow_any_instance_of(Api::V1::BaseController).to receive(:skip_auth?).and_return(true)
  end

  describe "GET #show" do
    context "when there is no current user" do
      it "returns unauthorized" do
        allow_any_instance_of(Api::V1::BaseController).to receive(:current_user).and_return(nil)

        get :show

        expect(response).to have_http_status(:unauthorized)
        body = JSON.parse(response.body)
        expect(body["error"]).to eq("Unauthorized")
      end
    end

    context "when current user exists" do
      it "returns the user's api keys as strings" do
        user = instance_double("User", llm_api_key: "llm123", tavily_api_key: nil)
        allow_any_instance_of(Api::V1::BaseController).to receive(:current_user).and_return(user)

        get :show

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["llmApiKey"]).to eq("llm123")
        expect(body["tavilyApiKey"]).to eq("")
      end
    end
  end

  describe "PATCH #update" do
    context "when there is no current user" do
      it "returns unauthorized" do
        allow_any_instance_of(Api::V1::BaseController).to receive(:current_user).and_return(nil)

        patch :update

        expect(response).to have_http_status(:unauthorized)
        body = JSON.parse(response.body)
        expect(body["error"]).to eq("Unauthorized")
      end
    end

    context "when user exists" do
      let(:user) { instance_double("User") }

      before do
        allow_any_instance_of(Api::V1::BaseController).to receive(:current_user).and_return(user)
      end

      it "returns current keys when no update params provided" do
        allow(user).to receive(:llm_api_key).and_return("a")
        allow(user).to receive(:tavily_api_key).and_return("b")

        patch :update, params: {}

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["llmApiKey"]).to eq("a")
        expect(body["tavilyApiKey"]).to eq("b")
      end

      it "updates llm_api_key when direct param provided and renders updated values" do
        allow(user).to receive(:tavily_api_key).and_return("old_tavily")
        expect(user).to receive(:update).with(hash_including(llm_api_key: "new_llm")).and_return(true)
        allow(user).to receive(:llm_api_key).and_return("new_llm")

        patch :update, params: { llmApiKey: "new_llm" }

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["llmApiKey"]).to eq("new_llm")
        expect(body["tavilyApiKey"]).to eq("old_tavily")
      end

      it "updates tavily_api_key when nested api_keys param provided" do
        allow(user).to receive(:llm_api_key).and_return("old_llm")
        expect(user).to receive(:update).with(hash_including(tavily_api_key: "new_tavily")).and_return(true)
        allow(user).to receive(:tavily_api_key).and_return("new_tavily")

        patch :update, params: { api_keys: { tavilyApiKey: "new_tavily" } }

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["tavilyApiKey"]).to eq("new_tavily")
        expect(body["llmApiKey"]).to eq("old_llm")
      end

      it "prefers direct params over nested params when both provided" do
        allow(user).to receive(:tavily_api_key).and_return("tavily_val")
        expect(user).to receive(:update).with(hash_including(llm_api_key: "direct_val")).and_return(true)
        allow(user).to receive(:llm_api_key).and_return("direct_val")

        patch :update, params: { llmApiKey: "direct_val", api_keys: { llmApiKey: "nested_val" } }

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["llmApiKey"]).to eq("direct_val")
      end

      it "returns unprocessable_entity with errors when update fails" do
        allow(user).to receive(:llm_api_key).and_return("before")
        errors = double(full_messages: [ "error" ])
        expect(user).to receive(:update).and_return(false)
        allow(user).to receive(:errors).and_return(errors)

        patch :update, params: { llmApiKey: "x" }

        expect(response).to have_http_status(:unprocessable_entity)
        body = JSON.parse(response.body)
        expect(body["error"]).to eq([ "error" ])
      end
    end
  end
end
