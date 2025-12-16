Rails.application.configure do
  # Active Record Encryption keys
  #
  # Generate keys with:
  #   bin/rails db:encryption:init
  #
  # Then store them EXACTLY as generated (no re-encoding) as environment variables:
  #   ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY
  #   ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY
  #   ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT
  #
  # Allow running the key generator task without pre-existing keys.
  running_encryption_init =
    ARGV.any? { |a| a == "db:encryption:init" || a.end_with?("db:encryption:init") }

  # Treat Heroku staging/review apps as production-like for encryption key presence.
  # Goal: fail fast if keys are missing, so we never encrypt with “mystery keys”
  # that make data unreadable later.
  production_like =
    Rails.env.production? ||
      ENV["DYNO"].present? ||
      ENV["HEROKU_APP_NAME"].present? ||
      ENV["RAILS_ENV"].to_s == "staging"

  # Source of truth:
  # - production-like: ENV only (so deploy fails fast if missing)
  # - non-production: ENV preferred, fallback to credentials
  env_primary = ENV["ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY"].presence
  env_deterministic = ENV["ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY"].presence
  env_salt = ENV["ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT"].presence

  cred = Rails.application.credentials[:active_record_encryption]
  cred_primary = cred && cred[:primary_key].presence
  cred_deterministic = cred && cred[:deterministic_key].presence
  cred_salt = cred && cred[:key_derivation_salt].presence

  resolved_primary = env_primary || (!production_like ? cred_primary : nil)
  resolved_deterministic = env_deterministic || (!production_like ? cred_deterministic : nil)
  resolved_salt = env_salt || (!production_like ? cred_salt : nil)

  # Key rotation (same encryption scheme, new keys):
  # Rails supports rotation by configuring multiple PRIMARY keys; the last key
  # is used for new writes and all keys are tried for decryption.
  #
  # Set optional old keys (comma-separated):
  #   ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY_OLD="old1,old2"
  normalize_key_list = lambda do |value|
    case value
    when Array
      value.map { |v| v.to_s.strip }.reject(&:empty?)
    when String
      value.split(",").map(&:strip).reject(&:empty?)
    when nil
      []
    else
      [ value.to_s.strip ].reject(&:empty?)
    end
  end

  old_primary_keys = normalize_key_list.call(ENV["ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY_OLD"])

  unless running_encryption_init
    missing = []
    missing << "ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY" if resolved_primary.blank?
    missing << "ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY" if resolved_deterministic.blank?
    missing << "ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT" if resolved_salt.blank?

    if missing.any?
      raise <<~MSG
        Missing Active Record Encryption configuration: #{missing.join(", ")}.

        Generate keys with:
          bin/rails db:encryption:init

        Then store them EXACTLY as generated.

        Production-like envs (production/staging/review): set them as ENV vars.
        Development: set ENV vars OR add to credentials under:

          active_record_encryption:
            primary_key: ...
            deterministic_key: ...
            key_derivation_salt: ...
      MSG
    end
  end

  primary_keys = old_primary_keys + normalize_key_list.call(resolved_primary)
  config.active_record.encryption.primary_key = primary_keys
  config.active_record.encryption.deterministic_key = resolved_deterministic
  config.active_record.encryption.key_derivation_salt = resolved_salt

  # Optional perf win when multiple keys exist: store key reference in ciphertext
  # so decryption doesn't need to try every key.
  config.active_record.encryption.store_key_references = primary_keys.length > 1

  # Catch schema mistakes early (e.g., encrypted strings that are too small).
  config.active_record.encryption.validate_column_size = true

  # Belt-and-suspenders: automatically add encrypted attributes to
  # filter_parameters so they don't leak via request logs.
  config.active_record.encryption.add_to_filter_parameters = true
end
