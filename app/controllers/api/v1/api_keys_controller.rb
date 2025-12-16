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

        updates = {}
        api_key_hash = nil

        # Handle scalar :api_key parameter first (use require to avoid strong params warning)
        # params.require(:api_key) doesn't trigger strong params warning for scalars
        begin
          api_key_val = params.require(:api_key)
          # If it's a scalar (not Hash/Parameters), use it directly and return
          unless api_key_val.is_a?(Hash) || api_key_val.is_a?(ActionController::Parameters)
            user.update!(llm_api_key: api_key_val)
            render json: {
              llmApiKey: user.llm_api_key.to_s,
              tavilyApiKey: user.tavily_api_key.to_s
            }
            return
          end
          # If it's a Hash, store it for nested handling below
          api_key_hash = api_key_val
        rescue ActionController::ParameterMissing
          # :api_key not present, continue to other formats
        end

        # Accept both legacy and current param shapes:
        # - top-level { llmApiKey, tavilyApiKey }
        # - nested { api_keys: { ... } } (frontend)
        # - nested { api_key: { ... } } (older - use the Hash we already retrieved above)
        direct = params.permit(:llmApiKey, :tavilyApiKey, :llm_api_key, :tavily_api_key)

        # For nested case, use the api_key Hash we already retrieved, or check api_keys
        nested_raw = params[:api_keys] || api_key_hash || {}
        nested_params =
          if nested_raw.is_a?(ActionController::Parameters)
            nested_raw
          elsif nested_raw.is_a?(Hash)
            ActionController::Parameters.new(nested_raw)
          else
            ActionController::Parameters.new({})
          end
        nested = nested_params.permit(:llmApiKey, :tavilyApiKey, :llm_api_key, :tavily_api_key)

        llm_val =
          direct[:llmApiKey] ||
          direct[:llm_api_key] ||
          nested[:llmApiKey] ||
          nested[:llm_api_key]

        tavily_val =
          direct[:tavilyApiKey] ||
          direct[:tavily_api_key] ||
          nested[:tavilyApiKey] ||
          nested[:tavily_api_key]

        # Allow clearing keys by explicitly sending empty string.
        updates[:llm_api_key] = llm_val unless llm_val.nil?
        updates[:tavily_api_key] = tavily_val unless tavily_val.nil?

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
            error: user.errors.full_messages
          }, status: :unprocessable_entity
        end
      end
    end
  end
end
