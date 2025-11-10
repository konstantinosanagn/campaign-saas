class AddSharedSettingsToCampaigns < ActiveRecord::Migration[8.1]
  def change
    add_column :campaigns, :shared_settings, :jsonb, default: {}, null: false
  end
end
