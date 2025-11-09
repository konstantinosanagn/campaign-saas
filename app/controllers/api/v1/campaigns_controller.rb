module Api
  module V1
    class CampaignsController < BaseController
      def index
        # Only return campaigns belonging to the current user
        render json: current_user.campaigns
      end

      def create
        # Associate campaign with current user
        campaign = current_user.campaigns.build(campaign_params)
        if campaign.save
          render json: campaign, status: :created
        else
          render json: { errors: campaign.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        # Only allow updating campaigns that belong to current user
        campaign = current_user.campaigns.find_by(id: params[:id])
        if campaign && campaign.update(campaign_params)
          render json: campaign
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
        campaign = current_user.campaigns.find_by(id: params[:id])

        unless campaign
          render json: { errors: [ "Campaign not found or unauthorized" ] }, status: :not_found
          return
        end

        begin
          result = EmailSenderService.send_emails_for_campaign(campaign)

          render json: {
            success: true,
            sent: result[:sent],
            failed: result[:failed],
            errors: result[:errors]
          }, status: :ok
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
        params_hash = params.require(:campaign).permit(:title, :basePrompt).to_h.with_indifferent_access
        params_hash[:base_prompt] = params_hash.delete(:basePrompt) if params_hash[:basePrompt]
        params_hash
      end
    end
  end
end
