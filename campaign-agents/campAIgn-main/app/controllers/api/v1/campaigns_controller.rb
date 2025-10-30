class Api::V1::CampaignsController < ApplicationController
  before_action :set_cors_headers

  def create
    begin
      result = Orchestrator.run(
        campaign_params[:company_name],
        recipient: campaign_params[:recipient],
        product_info: campaign_params[:product_info],
        sender_company: campaign_params[:sender_company]
      )

      render json: {
        success: true,
        data: {
          company: result[:company],
          recipient: result[:recipient],
          email: result[:email],
          critique: result[:critique],
          sources: result[:sources],
          product_info: result[:product_info],
          sender_company: result[:sender_company],
          generated_at: Time.current.iso8601
        }
      }, status: :ok
    rescue => e
      render json: {
        success: false,
        error: e.message,
        backtrace: Rails.env.development? ? e.backtrace : nil
      }, status: :internal_server_error
    end
  end

  def health
    render json: {
      status: 'healthy',
      timestamp: Time.current.iso8601,
      version: '1.0.0'
    }
  end

  private

  def campaign_params
    params.permit(:company_name, :recipient, :product_info, :sender_company)
  end

  def set_cors_headers
    headers['Access-Control-Allow-Origin'] = '*'
    headers['Access-Control-Allow-Methods'] = 'POST, GET, OPTIONS'
    headers['Access-Control-Allow-Headers'] = 'Content-Type'
  end
end
