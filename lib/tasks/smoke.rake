require "json"
require "securerandom"

namespace :smoke do
  desc "Verify encrypted secret writes + dual-read safety (requires SMOKE_USER_ID)"
  task encrypted_secrets: :environment do
    user_id = ENV.fetch("SMOKE_USER_ID")
    user = User.find(user_id)

    llm_val = "smoke_llm_#{SecureRandom.hex(6)}"
    tavily_val = "smoke_tavily_#{SecureRandom.hex(6)}"

    user.update!(llm_api_key: llm_val, tavily_api_key: tavily_val)

    raw =
      ActiveRecord::Base.connection
        .exec_query("SELECT llm_api_key, tavily_api_key FROM users WHERE id = #{user.id.to_i}")
        .first || {}

    db_contains_plaintext =
      raw["llm_api_key"].to_s.include?(llm_val) ||
        raw["tavily_api_key"].to_s.include?(tavily_val)

    user.reload
    read_ok = (user.llm_api_key == llm_val) && (user.tavily_api_key == tavily_val)

    result = {
      ok: (read_ok && !db_contains_plaintext),
      read_ok: read_ok,
      db_contains_plaintext: db_contains_plaintext,
      user_id: user.id
    }

    puts(result.to_json)
    abort("smoke:encrypted_secrets failed") unless result[:ok]
  end

  desc "Refresh Gmail OAuth tokens for internal accounts (requires SMOKE_OAUTH_USER_IDS)"
  task oauth_refresh: :environment do
    ids = ENV.fetch("SMOKE_OAUTH_USER_IDS", "")
             .split(",")
             .map(&:strip)
             .reject(&:empty?)

    abort("SMOKE_OAUTH_USER_IDS is required") if ids.empty?

    all_ok = true

    ids.each do |id|
      begin
        user = User.find(id)
        GoogleOauthTokenRefresher.refresh!(user)
        puts({ ok: true, user_id: user.id }.to_json)
      rescue => e
        all_ok = false
        puts({ ok: false, user_id: id, error: "#{e.class}: #{e.message}" }.to_json)
      end
    end

    abort("smoke:oauth_refresh failed") unless all_ok
  end
end
