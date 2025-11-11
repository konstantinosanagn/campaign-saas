FactoryBot.define do
  factory :agent_output do
    association :lead
    agent_name { 'SEARCH' }
    output_data do
      {
        sources: [],
        domain: { domain: 'example.com', sources: [] },
        recipient: { name: 'John Doe', sources: [] }
      }
    end
    status { 'pending' }
  end

  factory :agent_output_search, class: AgentOutput do
    association :lead
    agent_name { 'SEARCH' }
    output_data do
      {
        sources: [
          { title: 'Article 1', url: 'https://example.com/1', content: 'Content 1' },
          { title: 'Article 2', url: 'https://example.com/2', content: 'Content 2' }
        ],
        domain: { domain: 'example.com', sources: [
          { title: 'Article 1', url: 'https://example.com/1', content: 'Content 1' },
          { title: 'Article 2', url: 'https://example.com/2', content: 'Content 2' }
        ] },
        recipient: { name: 'John Doe', sources: [] }
      }
    end
    status { 'completed' }
  end

  factory :agent_output_writer, class: AgentOutput do
    association :lead
    agent_name { 'WRITER' }
    output_data do
      {
        email: "Subject: Test Email\n\nBody of the email",
        company: 'Example Corp',
        recipient: 'John Doe',
        sources: [],
        product_info: nil,
        sender_company: nil
      }
    end
    status { 'completed' }
  end

  factory :agent_output_critique, class: AgentOutput do
    association :lead
    agent_name { 'CRITIQUE' }
    output_data { { critique: 'The email looks good but could be more personalized.' } }
    status { 'completed' }
  end

  factory :agent_output_design, class: AgentOutput do
    association :lead
    agent_name { 'DESIGN' }
    output_data do
      {
        email: "Subject: Test Email\n\n**Body** of the email",
        formatted_email: "Subject: Test Email\n\n**Body** of the email",
        company: 'Example Corp',
        recipient: 'John Doe',
        original_email: "Subject: Test Email\n\nBody of the email"
      }
    end
    status { 'completed' }
  end

  factory :agent_output_failed, class: AgentOutput do
    association :lead
    agent_name { 'WRITER' }
    output_data { { error: 'API key is invalid' } }
    status { 'failed' }
    error_message { 'API key is invalid' }
  end
end
