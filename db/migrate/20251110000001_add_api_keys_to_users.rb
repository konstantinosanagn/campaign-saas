class AddApiKeysToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :llm_api_key, :string
    add_column :users, :tavily_api_key, :string

    add_index :users, :llm_api_key
    add_index :users, :tavily_api_key
  end
end
