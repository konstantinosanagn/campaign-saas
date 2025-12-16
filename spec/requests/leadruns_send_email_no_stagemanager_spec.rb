require "rails_helper"

RSpec.describe "LeadRuns: send_email does not invoke StageManagerFacade", type: :request do
  let(:headers) { { "Accept" => "application/json" } }

  it "POST /api/v1/leads/:id/send_email works without StageManager constants" do
    user = create(:user)
    campaign = create(:campaign, user: user)
    lead = create(:lead, campaign: campaign)

    # Create SENDER agent config
    create(:agent_config, campaign: campaign, agent_name: AgentConstants::AGENT_SENDER, enabled: true)

    # Configure email sending
    user.update!(gmail_access_token: 'token', gmail_refresh_token: 'refresh', gmail_email: 'test@gmail.com')

    # Create a completed DESIGN output
    run = create(:lead_run, lead: lead, campaign: campaign, status: 'completed')
    design_step = create(:lead_run_step, lead_run: run, agent_name: AgentConstants::AGENT_DESIGN, status: 'completed', position: 40)
    create(:agent_output,
      lead: lead,
      lead_run: run,
      lead_run_step: design_step,
      agent_name: AgentConstants::AGENT_DESIGN,
      status: 'completed',
      output_data: { 'formatted_email' => 'Subject: Test\n\nBody content' }
    )

    sign_in user

    # Mock job enqueue
    job_double = double(job_id: 'job-123')
    allow(AgentExecutionJob).to receive(:perform_later).and_return(job_double)

    post "/api/v1/leads/#{lead.id}/send_email", headers: headers
    expect(response).to have_http_status(:accepted)
    json_response = JSON.parse(response.body)
    expect(json_response['success']).to be true
    expect(json_response['jobId']).to eq('job-123')
    expect(defined?(LeadAgentService::StageManager)).to be_nil
  end
end
