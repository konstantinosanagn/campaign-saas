module Api
  module V1
    class ApiKeysController < BaseController
      def show
        render json: {
          llmApiKey: session[:llm_api_key] || '',
          tavilyApiKey: session[:tavily_api_key] || ''
        }
      end

      def update
        # Handle both nested and direct parameters
        llm_key = params[:llmApiKey] || params.dig(:api_keys, :llmApiKey)
        tavily_key = params[:tavilyApiKey] || params.dig(:api_keys, :tavilyApiKey)
        
        session[:llm_api_key] = llm_key
        session[:tavily_api_key] = tavily_key
        
        render json: { 
          llmApiKey: session[:llm_api_key],
          tavilyApiKey: session[:tavily_api_key]
        }
      end
    end
  end
end


