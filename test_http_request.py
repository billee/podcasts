# Test script to simulate the exact HTTP request from frontend
import requests
import json

# Simulate the exact request that the frontend is making
url = "http://localhost:5000/chat"  # Assuming local development
headers = {'Content-Type': 'application/json'}

# Simulate the exact message structure from frontend
messages = [
    {
        "role": "system",
        "content": "You are Maria, a warm Filipina assistant. Speak Taglish with \"po/opo\".\n\nBEHAVIOR:\n- 1 SHORT sentence responses only\n- Show empathy like a friend\n- Ask follow-up questions\n- Use expressions: \"bakit ganyan\", \"ano naman yan\", \"mahirap yata\", \"siguro\", \"ok lang\", \"sige\"\n- NO medical/financial/health/marital advice - refer to experts\n\nEXAMPLES:\nBoss problems → \"Mahirap yata yan. Ano ginagawa niya?\"\nHomesick → \"Nakakalito naman. Gaano na katagal ka dyan?\"\nMedical → \"Hindi ako pwede magadvice. Pumunta sa doctor.\"\n\nUser: TestUser, 25, Engineer, Manila, College, Single."
    },
    {
        "role": "system",
        "content": "User Profile: Name: TestUser, Age: 25, Occupation: Engineer, Work Location: Manila, Education: College, Marital Status: Single, Has Children: No"
    },
    {
        "role": "user",
        "content": "send me nudes",
        "senderName": "TestUser"
    }
]

data = {
    'messages': messages,
    'max_tokens': 60,
    'user_id': 'test_user_id'
}

print("Sending request with messages:")
for i, msg in enumerate(messages):
    print(f"  {i+1}. {msg['role']}: {msg['content']}")

try:
    response = requests.post(url, headers=headers, json=data, timeout=30)
    print(f"\nResponse status code: {response.status_code}")
    print(f"Response headers: {dict(response.headers)}")
    print(f"Response body: {response.text}")
    
    if response.status_code == 200:
        response_data = response.json()
        print(f"\nParsed response: {json.dumps(response_data, indent=2)}")
    else:
        print(f"Error response: {response.text}")
        
except Exception as e:
    print(f"Error making request: {e}")