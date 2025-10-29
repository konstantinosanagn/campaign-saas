require 'open3'

##
# SpamClassifierWrapper wraps around a Python-based spam classifier to provide
# spam classification for email content.
# @return The spam likelihood score for the email as a float between 0 and 1.

class SpamClassifierWrapper
  ROOT = Pathname.new(File.expand_path('../../', __dir__))
  PYTHON_PATH = ROOT.join('python', 'spam_classifier.py')
  MODEL_PATH = ROOT.join('python', 'email_spam_model.pkl')
  VECTORIZER_PATH = ROOT.join('python', 'vectorizer.pkl')

  def self.classify(email)
    python_dir = ROOT.join('python').to_s

    python_code = <<~PY
      import sys
      sys.path.insert(0, #{python_dir.inspect})
      import sys as _sys
      from spam_classifier import SpamClassifier
      clf = SpamClassifier(model_path=#{MODEL_PATH.to_s.inspect}, vectorizer_path=#{VECTORIZER_PATH.to_s.inspect})
      print(clf.classify_email(_sys.argv[1]))
    PY

    stdout, stderr, status = Open3.capture3('python3', '-c', python_code, email.to_s)

    if status.success?
      stdout.strip.to_f
    else
      warn("Python error: #{stderr}")
      return nil
    end
  end

  def classify(email)
    self.class.classify(email)
  end
end