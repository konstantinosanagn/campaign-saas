# Stub Webpacker helpers for test environment
# This prevents Webpacker::Manifest::MissingEntryError when rendering views in tests

RSpec.configure do |config|
  config.before(:each, type: :request) do
    # Stub the javascript_pack_tag helper to avoid Webpacker manifest lookup
    allow_any_instance_of(ActionView::Base).to receive(:javascript_pack_tag) do |*args|
      '<script src="/packs/application.js"></script>'.html_safe
    end
    
    # Stub stylesheet_pack_tag if needed
    allow_any_instance_of(ActionView::Base).to receive(:stylesheet_pack_tag) do |*args|
      '<link rel="stylesheet" href="/packs/application.css">'.html_safe
    end
  end
end

