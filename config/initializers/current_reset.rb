# Reset Current attributes on code reload (development) to prevent stale state
# in rails console, rake tasks, and other non-request execution paths
ActiveSupport::Reloader.to_complete do
  Current.reset
end
