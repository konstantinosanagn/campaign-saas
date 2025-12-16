class ChangeUserApiKeysToText < ActiveRecord::Migration[8.1]
  def change
    # Encrypted payloads can exceed 255 chars; keeping these as :string risks
    # truncation (catastrophic). Use :text.
    change_column :users, :llm_api_key, :text
    change_column :users, :tavily_api_key, :text

    # These were added when the columns were plaintext. Once encrypted with
    # non-deterministic encryption, they are not meaningfully queryable and
    # add write overhead.
    remove_index :users, :llm_api_key, if_exists: true
    remove_index :users, :tavily_api_key, if_exists: true
  end
end
