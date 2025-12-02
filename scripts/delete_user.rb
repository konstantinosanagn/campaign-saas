# Rails console script to delete user: kaean2002trikala@gmail.com
#
# Usage in Rails console (production):
#   load 'scripts/delete_user.rb'
#
# Or copy-paste the contents into Rails console

email = 'kaean2002trikala@gmail.com'
user = User.find_by(email: email)

unless user
  puts "User with email '#{email}' not found."
  exit
end

# Show summary of what will be deleted
campaigns = user.campaigns
campaigns_count = campaigns.count
leads_count = campaigns.joins(:leads).count
agent_configs_count = campaigns.joins(:agent_configs).count
agent_outputs_count = AgentOutput.joins(lead: :campaign).where(campaigns: { user_id: user.id }).count

puts "\n" + "="*60
puts "WARNING: This will permanently delete the following:"
puts "="*60
puts "User: #{user.email} (ID: #{user.id})"
puts "  Name: #{user.name || 'N/A'}"
puts "  Created: #{user.created_at}"
puts "  - Campaigns: #{campaigns_count}"
puts "  - Leads: #{leads_count}"
puts "  - Agent Configs: #{agent_configs_count}"
puts "  - Agent Outputs: #{agent_outputs_count}"
puts "="*60
puts "\nThis action CANNOT be undone!"

# Uncomment the line below to actually delete
# user.destroy!
puts "\nTo delete, uncomment 'user.destroy!' in the script and run again."
