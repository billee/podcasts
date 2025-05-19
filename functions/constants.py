
class AppConstants:
    # Existing cached responses
    cachedResponses = {
        'homesick': [
            'Alam kong mahirap malayo sa pamilya. Kaya mo yan, kabayan!',
            'Gusto mo bang mag-schedule ng video call sa inyong pamilya?'
        ],
        'oec': [
            'Para sa OEC renewal, kailangan ng: 1) Passport, 2) Kontrata, 3) OWWA membership. Pwede ko bang i-direct sa official website?',
        ],
    }



    # Phase 1 additions
    government_guides = {
        'oec_process': {
            'content': '''Official OEC Renewal Steps:
1. Kumpletuhin ang mga dokumento:
   - Valid passport
   - Valid work visa
   - Employment contract
2. Mag-register sa DMW Online System
3. Mag-schedule ng appointment''',
            'metadata': {
                'category': 'legal',
                'country': 'all',
                'source': 'gov',
                'freshness': '2024-01-01'
            }
        }
    }

    cultural_scripts = {
        'mindfulness': {
            'content': '''Mindfulness Exercise (Taglish):
Maghanap ng tahimik na lugar. Huminga ng malalim... 
"Let go of stress, kapatid. Isipin mo ang mga anak mo sa Pinas."''',
            'metadata': {
                'category': 'emotional',
                'country': 'all',
                'source': 'curated',
                'freshness': '2024-01-01'
            }
        }
    }