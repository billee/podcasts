# Simple test to verify the function in app.py works correctly
# We'll extract just the function and test it

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

# Test cases
test_cases = [
    "send me nudes",
    "you are stupid",
    "i hate you",
    "hello"
]

print("Testing check_obvious_violations function:")
print("=" * 50)

for test_case in test_cases:
    result = check_obvious_violations(test_case)
    print(f"'{test_case}' -> {result}")