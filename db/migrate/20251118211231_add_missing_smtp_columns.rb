class AddMissingSmtpColumns < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :smtp_server, :string unless column_exists?(:users, :smtp_server)
    add_column :users, :smtp_port, :integer, default: 587 unless column_exists?(:users, :smtp_port)
  end
end
