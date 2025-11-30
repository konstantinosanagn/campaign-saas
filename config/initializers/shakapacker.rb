# Backup: Monkey-patch Shakapacker to skip packageManager check if yarn.lock exists
# This is a safety net in case the PACKAGE_JSON_FALLBACK_MANAGER env var isn't picked up
if File.exist?(Rails.root.join('yarn.lock')) && defined?(Shakapacker::Utils::Manager)
  Shakapacker::Utils::Manager.class_eval do
    alias_method :original_error_unless_package_manager_is_obvious!, :error_unless_package_manager_is_obvious!
    
    def error_unless_package_manager_is_obvious!
      # Skip the packageManager check if yarn.lock exists
      # This allows Heroku builds to work without corepack
      return if File.exist?(Rails.root.join('yarn.lock'))
      original_error_unless_package_manager_is_obvious!
    end
  end
end
