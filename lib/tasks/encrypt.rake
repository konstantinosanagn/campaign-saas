namespace :encrypt do
  desc "Encrypt plaintext API keys (Gemini/Tavily) in users table"
  task api_keys: :environment do
    dry_run = ENV.fetch("DRY_RUN", "false") == "true"
    resume_from_id = ENV["RESUME_FROM_ID"]&.to_i
    batch_size = Integer(ENV.fetch("BATCH_SIZE", 500))

    # IMPORTANT:
    # Adjust these patterns to match your real plaintext key formats.
    llm_like = ENV.fetch("LLM_API_KEY_PLAINTEXT_LIKE", "AIza%")
    tavily_like = ENV.fetch("TAVILY_API_KEY_PLAINTEXT_LIKE", "tvly-%")

    if ENV.fetch("NORMALIZE_BLANKS", "false") == "true"
      Rails.logger.info("[encrypt:api_keys] normalizing blank/whitespace keys to NULL")
      User.where("llm_api_key IS NOT NULL AND BTRIM(llm_api_key) = ''").update_all(llm_api_key: nil)
      User.where("tavily_api_key IS NOT NULL AND BTRIM(tavily_api_key) = ''").update_all(tavily_api_key: nil)
    end

    scope = User.where("llm_api_key LIKE ? OR tavily_api_key LIKE ?", llm_like, tavily_like)
    scope = scope.where("id > ?", resume_from_id) if resume_from_id.present? && resume_from_id > 0
    scope = scope.order(:id)

    matched_count = scope.count
    Rails.logger.info("[encrypt:api_keys] start dry_run=#{dry_run} resume_from_id=#{resume_from_id.inspect} batch_size=#{batch_size} matched_count=#{matched_count} llm_like=#{llm_like.inspect} tavily_like=#{tavily_like.inspect}")

    processed_count = 0
    failed_count = 0
    last_id = resume_from_id

    scope.in_batches(of: batch_size) do |batch|
      batch.each do |user|
        last_id = user.id
        begin
          # Accessors may read from plaintext or ciphertext depending on rollout state.
          # Writing back the same value will encrypt at rest.
          llm = user.llm_api_key
          tavily = user.tavily_api_key

          if dry_run
            processed_count += 1
            next
          end

          user.llm_api_key = llm
          user.tavily_api_key = tavily
          user.save!(validate: false)
          processed_count += 1
        rescue => e
          failed_count += 1
          # Never log decrypted values. Keep logs to user_id + error class/message only.
          Rails.logger.error("[encrypt:api_keys] user_id=#{user.id} error=#{e.class}: #{e.message}")
        end
      end

      Rails.logger.info("[encrypt:api_keys] batch processed_count=#{processed_count} failed_count=#{failed_count} last_id=#{last_id}")
    end

    Rails.logger.info("[encrypt:api_keys] done matched_count=#{matched_count} processed_count=#{processed_count} failed_count=#{failed_count} last_id=#{last_id}")
  end

  desc "Encrypt Gmail OAuth tokens in users table (safe to rerun; may rewrite ciphertext)"
  task oauth_tokens: :environment do
    dry_run = ENV.fetch("DRY_RUN", "false") == "true"
    resume_from_id = ENV["RESUME_FROM_ID"]&.to_i
    batch_size = Integer(ENV.fetch("BATCH_SIZE", 500))

    scope = User.where("gmail_access_token IS NOT NULL OR gmail_refresh_token IS NOT NULL")
    scope = scope.where("id > ?", resume_from_id) if resume_from_id.present? && resume_from_id > 0
    scope = scope.order(:id)

    matched_count = scope.count
    Rails.logger.info("[encrypt:oauth_tokens] start dry_run=#{dry_run} resume_from_id=#{resume_from_id.inspect} batch_size=#{batch_size} matched_count=#{matched_count}")

    processed_count = 0
    failed_count = 0
    last_id = resume_from_id

    scope.in_batches(of: batch_size) do |batch|
      batch.each do |user|
        last_id = user.id
        begin
          access = user.gmail_access_token
          refresh = user.gmail_refresh_token

          if dry_run
            processed_count += 1
            next
          end

          user.gmail_access_token = access
          user.gmail_refresh_token = refresh
          user.save!(validate: false)
          processed_count += 1
        rescue => e
          failed_count += 1
          # Never log decrypted values. Keep logs to user_id + error class/message only.
          Rails.logger.error("[encrypt:oauth_tokens] user_id=#{user.id} error=#{e.class}: #{e.message}")
        end
      end

      Rails.logger.info("[encrypt:oauth_tokens] batch processed_count=#{processed_count} failed_count=#{failed_count} last_id=#{last_id}")
    end

    Rails.logger.info("[encrypt:oauth_tokens] done matched_count=#{matched_count} processed_count=#{processed_count} failed_count=#{failed_count} last_id=#{last_id}")
  end
end
