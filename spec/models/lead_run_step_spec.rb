require "rails_helper"

RSpec.describe LeadRunStep, type: :model do
  it { is_expected.to belong_to(:lead_run) }
  it { is_expected.to belong_to(:agent_output).optional }

  it { is_expected.to validate_presence_of(:position) }
  it { is_expected.to validate_presence_of(:agent_name) }
  it { is_expected.to validate_presence_of(:status) }
end
