FactoryBot.define do
  factory :lead_run do
    association :lead
    association :campaign
    status { "queued" }
    min_score { 6 }
    max_rewrites { 2 }
    rewrite_count { 0 }
    plan { {} }
    config_snapshot { {} }
  end

  factory :lead_run_running, class: LeadRun do
    association :lead
    association :campaign
    status { "running" }
    min_score { 6 }
    max_rewrites { 2 }
    rewrite_count { 0 }
    plan { {} }
    config_snapshot { {} }
    started_at { Time.current }
  end

  factory :lead_run_completed, class: LeadRun do
    association :lead
    association :campaign
    status { "completed" }
    min_score { 6 }
    max_rewrites { 2 }
    rewrite_count { 0 }
    plan { {} }
    config_snapshot { {} }
    started_at { Time.current }
    finished_at { Time.current }
  end

  factory :lead_run_failed, class: LeadRun do
    association :lead
    association :campaign
    status { "failed" }
    min_score { 6 }
    max_rewrites { 2 }
    rewrite_count { 0 }
    plan { {} }
    config_snapshot { {} }
    started_at { Time.current }
    finished_at { Time.current }
  end
end
