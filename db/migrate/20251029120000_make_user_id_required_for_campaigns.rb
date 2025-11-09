class MakeUserIdRequiredForCampaigns < ActiveRecord::Migration[8.1]
  def up
    # Assign any orphaned campaigns to the first user (or create a default user)
    if Campaign.exists? && Campaign.where(user_id: nil).exists?
      default_user = User.first || User.create!(
        email: "system@example.com",
        password: SecureRandom.hex(16),
        password_confirmation: SecureRandom.hex(16),
        name: "System User"
      )
      Campaign.where(user_id: nil).update_all(user_id: default_user.id)
    end

    # Add NOT NULL constraint
    change_column_null :campaigns, :user_id, false
  end

  def down
    change_column_null :campaigns, :user_id, true
  end
end
