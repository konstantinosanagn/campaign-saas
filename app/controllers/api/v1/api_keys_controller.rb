module Api
  module V1
    class ApiKeysController < BaseController
      def show
        user = current_user

        unless user
          render json: { error: "Unauthorized" }, status: :unauthorized
          return
        end

        render json: {
          llmApiKey: user.llm_api_key.to_s,
          tavilyApiKey: user.tavily_api_key.to_s
        }
      end

      def update
        user = current_user

        unless user
          render json: { error: "Unauthorized" }, status: :unauthorized
          return
        end

        direct_params = params.permit(:llmApiKey, :tavilyApiKey)
        nested_params = params.fetch(:api_keys, {}).permit(:llmApiKey, :tavilyApiKey)

        updates = {}
        if direct_params.key?(:llmApiKey) || nested_params.key?(:llmApiKey)
          updates[:llm_api_key] = direct_params[:llmApiKey] || nested_params[:llmApiKey]
        end
        if direct_params.key?(:tavilyApiKey) || nested_params.key?(:tavilyApiKey)
          updates[:tavily_api_key] = direct_params[:tavilyApiKey] || nested_params[:tavilyApiKey]
        end

        if updates.empty?
          render json: {
            llmApiKey: user.llm_api_key.to_s,
            tavilyApiKey: user.tavily_api_key.to_s
          }
          return
        end

        if user.update(updates)
          render json: {
            llmApiKey: user.llm_api_key.to_s,
            tavilyApiKey: user.tavily_api_key.to_s
          }
        else
          render json: {
            error: user.errors.full_messages.join(", ")
          }, status: :unprocessable_entity
        end
      end
    end
  end
end
