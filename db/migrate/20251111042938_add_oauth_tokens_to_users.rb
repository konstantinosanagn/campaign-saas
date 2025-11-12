class AddOauthTokensToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :gmail_access_token, :text
    add_column :users, :gmail_refresh_token, :text
    add_column :users, :gmail_token_expires_at, :datetime
  end
end
