import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime

# Initialize Firebase
cred = credentials.Certificate("C:/Users/sanme/AndroidStudioProjects/kapwa_companion_basic/serviceAccountKey.json")
firebase_admin.initialize_app(cred)
db = firestore.client()

suggestions = [
    "Alamin ang iyong karapatan sa kontrata",
    "Paano mag-invest habang nasa abroad?",
    "Bakit kailangan ng emergency fund?",
    "Legal na proseso sa overwork",
    "Tax obligations ng OFWs sa Pinas",
    "Paano mag-upskill habang nagtratrabaho?",
    "Negosyo ideas pag-uwi sa Pinas",
    "Paano maging promotable sa trabaho?",
    "Skills na hinahanap sa abroad",
    "Paano mag-network sa industriya mo?",
    "Mga signs ng burnout sa trabaho",
    "Paano labanan ang homesickness effectively?",
    "Importance ng boundaries sa trabaho",
    "Paano humindi sa overtime abuse?",
    "Self-care habits para sa OFWs",
    "Paano turuan ang anak mag-save?",
    "Preparing for retirement as OFW",
    "Life insurance needs ng OFW",
    "Paano protektahan ang pamilya sa scam?",
    "Education plan para sa mga anak",
    "Health insurance requirements sa abroad",
    "Paano mag-file ng work injury?",
    "Mga hidden health risks sa work",
    "Mental health support para sa OFWs",
    "Safe remittance practices abroad",
    "Paano iwasan ang online scams?",
    "Secure na paraan ng pagse-send ng pera",
    "Protektahan ang social media accounts",
    "Mga phishing tactics na dapat iwasan",
    "Bakit kailangan ng VPN abroad?",
    "Cultural taboos sa bansa mo",
    "Paano makisama sa ibang lahi?",
    "Mga dapat iwasan sa workplace",
    "Paano i-handle ang discrimination?",
    "Language basics para sa survival",
    "Exit strategy para sa OFWs",
    "Paano mag-prepare para sa pag-uwi?",
    "Real estate tips para sa OFWs",
    "Paano mag-apply sa dual citizenship?",
    "Retirement countries na OFW-friendly",
    "Paano mag-report ng agency abuse?",
    "Legal recourses sa unpaid salary",
    "Bakit kailangan ng POEA documentation?",
    "Paano humingi ng day off?",
    "Workers' unions para sa OFWs",
    "Paano maging emotionally resilient abroad?",
    "Time management sa work-life balance",
    "Paano mag-set ng long-term goals?",
    "Building confidence sa foreign workplace",
    "Pag-handle ng workplace politics"
]

def upload_suggestions():
    collection_ref = db.collection('ofw_suggestions')
    
    for index, suggestion in enumerate(suggestions):
        doc_ref = collection_ref.document()
        doc_ref.set({
            'suggestion': suggestion,
            'language': 'tagalog',
            'word_count': 5,
            'created_at': datetime.now(),
            'order': index + 1,
            'target_audience': 'OFW'
        })
        print(f"Uploaded: {suggestion}")

    print("All suggestions uploaded successfully!")

if __name__ == "__main__":
    upload_suggestions()