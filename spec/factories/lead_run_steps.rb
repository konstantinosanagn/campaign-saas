FactoryBot.define do
  factory :lead_run_step do
    association :lead_run
    agent_name { "SEARCH" }
    position { 10 }
    status { "queued" }
    meta { {} }
  end

  factory :lead_run_step_running, class: LeadRunStep do
    association :lead_run
    agent_name { "SEARCH" }
    position { 10 }
    status { "running" }
    meta { {} }
    step_started_at { Time.current }
  end

  factory :lead_run_step_completed, class: LeadRunStep do
    association :lead_run
    agent_name { "SEARCH" }
    position { 10 }
    status { "completed" }
    meta { {} }
    step_started_at { Time.current }
    step_finished_at { Time.current }
  end

  factory :lead_run_step_failed, class: LeadRunStep do
    association :lead_run
    agent_name { "SEARCH" }
    position { 10 }
    status { "failed" }
    meta { {} }
    step_started_at { Time.current }
    step_finished_at { Time.current }
  end
end
