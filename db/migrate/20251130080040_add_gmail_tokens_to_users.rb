class AddGmailTokensToUsers < ActiveRecord::Migration[8.1]
  def change
    # gmail_access_token, gmail_refresh_token, and gmail_token_expires_at
    # already exist from a previous migration (20251111042938_add_oauth_tokens_to_users)
    # Only add the new gmail_email field
    add_column :users, :gmail_email, :string
  end
end
