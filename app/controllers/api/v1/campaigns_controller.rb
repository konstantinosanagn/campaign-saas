module Api
  module V1
    class CampaignsController < BaseController
      def index
        # Only return campaigns belonging to the current user
        # Use includes to prevent N+1 queries when accessing associations
        campaigns = current_user.campaigns.includes(:leads, :agent_configs)
        render json: CampaignSerializer.serialize_collection(campaigns)
      end

      def create
        # Associate campaign with current user
        campaign = current_user.campaigns.build(campaign_params)
        if campaign.save
          render json: CampaignSerializer.serialize(campaign), status: :created
        else
          render json: { errors: campaign.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        # Only allow updating campaigns that belong to current user
        campaign = current_user.campaigns.find_by(id: params[:id])
        if campaign && campaign.update(campaign_params)
          render json: CampaignSerializer.serialize(campaign)
        else
          render json: { errors: campaign ? campaign.errors.full_messages : [ "Not found or unauthorized" ] }, status: :unprocessable_entity
        end
      end

      def destroy
        # Only allow deleting campaigns that belong to current user
        campaign = current_user.campaigns.find_by(id: params[:id])
        if campaign
          campaign.destroy
          head :no_content
        else
          render json: { errors: [ "Not found or unauthorized" ] }, status: :not_found
        end
      end

      ##
      # POST /api/v1/campaigns/:id/send_emails
      # Sends emails to all ready leads in the campaign
      def send_emails
        # Use includes to prevent N+1 queries when loading leads and agent_outputs
        campaign = current_user.campaigns.includes(:leads, leads: :agent_outputs).find_by(id: params[:id])

        unless campaign
          render json: { errors: [ "Campaign not found or unauthorized" ] }, status: :not_found
          return
        end

        begin
          result = EmailSenderService.send_emails_for_campaign(campaign)

          render json: {
            success: true,
            queued: result[:queued],
            sent: result[:queued],  # For backward compatibility
            failed: result[:failed],
            errors: result[:errors],
            approx_duration_seconds: result[:approx_duration_seconds] || 0
          }, status: :ok
        rescue GmailAuthorizationError => e
          # Gmail token revoked/invalid - credentials already cleared by EmailSenderService
          render json: {
            success: false,
            error: e.message,
            requires_reconnect: true
          }, status: :unauthorized
        rescue => e
          render json: {
            success: false,
            error: e.message
          }, status: :internal_server_error
        end
      end

      private

      def campaign_params
        # Convert camelCase to snake_case for database
        params_hash = params.require(:campaign).permit(:title, sharedSettings: {}).to_h.with_indifferent_access

        # Handle sharedSettings - merge with existing if updating
        if params_hash[:sharedSettings]
          shared_settings = params_hash.delete(:sharedSettings)
          if params[:id]
            campaign = current_user.campaigns.find_by(id: params[:id])
            if campaign
              # Merge with existing shared_settings when updating
              # Use read_attribute to get actual DB value, not the getter with defaults
              existing = campaign.read_attribute(:shared_settings) || {}
              params_hash[:shared_settings] = existing.deep_merge(shared_settings)
            else
              params_hash[:shared_settings] = shared_settings
            end
          else
            # Use as-is when creating
            params_hash[:shared_settings] = shared_settings
          end
        end

        params_hash
      end
    end
  end
end
