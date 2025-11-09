# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

Rails.application.configure do
  config.content_security_policy do |policy|
    # Default policy: allow same origin and HTTPS
    policy.default_src :self, :https

    # Fonts: allow same origin, HTTPS, and data URIs (for inline fonts)
    policy.font_src :self, :https, :data

    # Images: allow same origin, HTTPS, and data URIs (for inline images)
    policy.img_src :self, :https, :data

    # Disable object/embed tags for security
    policy.object_src :none

    # Scripts: allow same origin, HTTPS, and unsafe-inline for Webpacker/Webpack
    # unsafe-inline is needed for Webpacker dev server and some React features
    policy.script_src :self, :https, :unsafe_inline, :unsafe_eval

    # Styles: allow same origin, HTTPS, and unsafe-inline for Tailwind CSS
    # unsafe-inline is needed for Tailwind's generated classes
    policy.style_src :self, :https, :unsafe_inline

    # Connect (AJAX/fetch): allow same origin and HTTPS
    policy.connect_src :self, :https

    # Frame ancestors: prevent clickjacking
    policy.frame_ancestors :none

    # Specify URI for violation reports (optional - configure endpoint if needed)
    # policy.report_uri "/csp-violation-report-endpoint"
  end

  # Generate session nonces for permitted importmap, inline scripts, and inline styles.
  config.content_security_policy_nonce_generator = ->(request) { request.session.id.to_s }
  config.content_security_policy_nonce_directives = %w[script-src style-src]

  # Automatically add `nonce` to `javascript_tag`, `javascript_include_tag`, and `stylesheet_link_tag`
  # if the corresponding directives are specified in `content_security_policy_nonce_directives`.
  # config.content_security_policy_nonce_auto = true

  # Report violations without enforcing the policy in development.
  # This allows us to see CSP violations in console without breaking the app.
  if Rails.env.development?
    config.content_security_policy_report_only = true
  end
end
