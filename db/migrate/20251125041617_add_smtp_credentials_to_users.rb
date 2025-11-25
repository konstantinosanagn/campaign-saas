class AddSmtpCredentialsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :smtp_username, :string
    add_column :users, :smtp_app_password, :string
  end
end
