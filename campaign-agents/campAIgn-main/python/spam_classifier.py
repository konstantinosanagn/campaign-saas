import joblib

class SpamClassifier:
    def __init__(self, model_path='email_spam_model.pkl', vectorizer_path='vectorizer.pkl'):
        self.model = joblib.load(model_path)
        self.vectorizer = joblib.load(vectorizer_path)

    def classify_email(self, email):
        transformed_email = self.vectorizer.transform([email])
        prediction = self.model.predict_proba(transformed_email)
        return prediction[0][1]