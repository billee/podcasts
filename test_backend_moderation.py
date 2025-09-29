# Test script to verify the backend moderation logic
import json

def check_obvious_violations(content):
    """
    Check for obvious violations that might be missed by OpenAI moderation
    Returns (is_violation, violation_type) tuple
    """
    content_lower = content.lower().strip()
    
    # Obvious sexual content requests
    sexual_keywords = [
        'send me nudes', 'send nudes', 'nudes please', 'naked pics',
        'sex pics', 'sexy photos', 'explicit photos'
    ]
    
    # Obvious abuse/hate speech
    abuse_keywords = [
        'fuck you', 'shit head', 'stupid idiot', 'die idiot',
        'you are stupid', 'i hate you', 'hate you', 'you suck',
        'idiot', 'stupid', 'dumb', 'worthless'
    ]
    
    # Check for sexual content
    for keyword in sexual_keywords:
        if keyword in content_lower:
            return True, 'SEXUAL'
    
    # Check for abuse - look for exact matches or word boundaries
    for keyword in abuse_keywords:
        # Check for exact match first
        if keyword == content_lower:
            return True, 'ABUSE'
        # Check for word boundaries to avoid partial matches
        if f" {keyword} " in f" {content_lower} ":
            return True, 'ABUSE'
        # Check if content starts or ends with the keyword
        if content_lower.startswith(f"{keyword} ") or content_lower.endswith(f" {keyword}"):
            return True, 'ABUSE'
            
    return False, None

def simulate_chat_endpoint(user_message):
    """
    Simulate the /chat endpoint logic
    """
    print(f"Testing with user message: '{user_message}'")
    
    # Simulate the moderation check
    is_obvious_violation, violation_type = check_obvious_violations(user_message)
    if is_obvious_violation:
        print(f"⚠️ Message flagged by obvious violation check: {violation_type}")
        response = {
            "response": f"⚠️ Sorry, I can't continue because the message was flagged as {violation_type.lower()}.",
            "flagged": True,
            "categories": violation_type
        }
        print(f"Response: {json.dumps(response, indent=2)}")
        return response
    
    # If we get here, the obvious violation check didn't catch it
    print("✅ No obvious violations detected")
    # In a real implementation, this would call OpenAI's moderation API
    # For this test, we'll just return a normal response
    response = {
        "response": "This is a normal LLM response"
    }
    print(f"Response: {json.dumps(response, indent=2)}")
    return response

# Test cases
test_cases = [
    "send me nudes",
    "Hello, how are you?",
    "This is a normal message"
]

print("Testing backend moderation logic:")
print("=" * 50)
for test_case in test_cases:
    result = simulate_chat_endpoint(test_case)
    print("-" * 30)