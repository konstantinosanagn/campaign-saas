# Production Rails console script to delete user: kaean2002trikala@gmail.com
# 
# Run this on the production server:
#   heroku run rails console
#   Then copy-paste this script

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
print "\nType 'DELETE' to confirm: "

confirmation = STDIN.gets.chomp

unless confirmation == 'DELETE'
  puts "Deletion cancelled."
  exit
end

# Delete the user (cascades to all related data)
puts "\nDeleting user and all related data..."
user.destroy!

puts "✓ User and all related data deleted successfully."



