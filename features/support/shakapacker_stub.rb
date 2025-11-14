# Stub Shakapacker helpers to avoid manifest lookups in Cucumber tests
module ActionView
  class Base
    def javascript_pack_tag(*args)
      '<script src="/packs/application.js"></script>'.html_safe
    end

    def stylesheet_pack_tag(*args)
      '<link rel="stylesheet" href="/packs/application.css">'.html_safe
    end
  end
end
