# Rate limiting configuration using rack-attack
# See: https://github.com/rack/rack-attack

class Rack::Attack
  # Skip rate limiting in test environment
  unless Rails.env.test?
    # Enable rate limiting
    # Use Redis in production, in-memory store in development
    if Rails.env.production?
      self.cache.store = ActiveSupport::Cache::RedisCacheStore.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'))
    else
      self.cache.store = ActiveSupport::Cache::MemoryStore.new
    end

  # Throttle all API requests by IP address
  # 100 requests per minute per IP
  throttle('api/ip', limit: 100, period: 1.minute) do |req|
    req.ip if req.path.start_with?('/api/')
  end

  # Throttle API write operations (create, update, delete) more strictly
  # 20 requests per minute per IP
  throttle('api/ip/write', limit: 20, period: 1.minute) do |req|
    req.ip if req.path.start_with?('/api/') && (req.post? || req.put? || req.patch? || req.delete?)
  end

  # ==========================================
  # Throttle by user ID (if authenticated)
  # ==========================================
  
  # Throttle authenticated requests by user ID
  # 300 requests per minute per user
  throttle('api/user', limit: 300, period: 1.minute) do |req|
    if req.path.start_with?('/api/')
      # Try to get user ID from Devise session
      user_id = req.session['warden.user.user.key']&.dig(0, 0) rescue nil
      user_id || "anonymous_#{req.ip}" # Fallback to IP if no session
    end
  end

  # Throttle authenticated write operations
  # 50 requests per minute per user
  throttle('api/user/write', limit: 50, period: 1.minute) do |req|
    if req.path.start_with?('/api/') && (req.post? || req.put? || req.patch? || req.delete?)
      user_id = req.session['warden.user.user.key']&.dig(0, 0) rescue nil
      user_id || "anonymous_#{req.ip}"
    end
  end

  # ==========================================
  # Throttle specific endpoints
  # ==========================================
  
  # Throttle login attempts
  # 5 login attempts per 20 minutes per IP
  throttle('logins/ip', limit: 5, period: 20.minutes) do |req|
    req.ip if req.path == '/users/sign_in' && req.post?
  end

  # Throttle password reset requests
  # 5 password resets per hour per IP
  throttle('password_resets/ip', limit: 5, period: 1.hour) do |req|
    req.ip if req.path == '/users/password' && req.post?
  end

  # ==========================================
  # Block suspicious requests
  # ==========================================
  
  # Block requests from known bad IPs (optional - configure as needed)
  # blocklist('block bad IPs') do |req|
  #   ['1.2.3.4', '5.6.7.8'].include?(req.ip)
  # end

  # ==========================================
  # Customize response when throttled
  # ==========================================
  
  self.throttled_responder = lambda do |request|
    match_data = request.env['rack.attack.match_data']
    retry_after = match_data[:period] if match_data
    
    [
      429, # status
      {
        'Content-Type' => 'application/json',
        'Retry-After' => retry_after.to_s
      },
      [{ error: 'Rate limit exceeded. Please try again later.' }.to_json]
    ]
  end

  # ==========================================
  # Development/testing helpers
  # ==========================================
  
  # Log when rate limiting is triggered (useful for debugging)
  if Rails.env.development?
    ActiveSupport::Notifications.subscribe('rack.attack') do |name, start, finish, request_id, payload|
      req = payload[:request]
      if req.env['rack.attack.match_type'] == :throttle
        Rails.logger.warn "[Rack::Attack] Throttled #{req.env['rack.attack.match_type']} #{req.ip} #{req.request_method} #{req.fullpath}"
      end
    end
  end
  end # unless Rails.env.test?
end
