FactoryBot.define do
  factory :agent_config do
    association :campaign
    agent_name { 'WRITER' }
    settings { {} }
    enabled { true }
  end

  factory :agent_config_writer, class: AgentConfig do
    association :campaign
    agent_name { 'WRITER' }
    settings do
      {
        'product_info' => 'AI-powered marketing automation tool',
        'sender_company' => 'TechCorp Solutions'
      }
    end
    enabled { true }
  end

  factory :agent_config_search, class: AgentConfig do
    association :campaign
    agent_name { 'SEARCH' }
    settings { {} }
    enabled { true }
  end

  factory :agent_config_critique, class: AgentConfig do
    association :campaign
    agent_name { 'CRITIQUE' }
    settings { {} }
    enabled { true }
  end

  factory :agent_config_disabled, class: AgentConfig do
    association :campaign
    agent_name { 'WRITER' }
    settings { {} }
    enabled { false }
  end
end

