# PACKAGE_JSON_FALLBACK_MANAGER is set in config/application.rb before Bundler.require
# This ensures Shakapacker uses npm when packageManager is not set in package.json
# No monkey-patch needed - the env var should be sufficient
