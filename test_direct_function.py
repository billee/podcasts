#!/usr/bin/env python3
"""
Direct test of the check_obvious_violations function
"""

# Direct implementation of the function as it should be in app.py
def check_obvious_violations(content):
    """
    Check for obvious violations that might be missed by OpenAI moderation
    Returns (is_violation, violation_type) tuple
    """
    print(f"=== CHECK_OBVIOUS_VIOLATIONS CALLED ===")
    print(f"Exact content received: '{content}'")
    print(f"Content length: {len(content)}")
    print(f"Content repr: {repr(content)}")
    print(f"Content type: {type(content)}")
    
    content_lower = content.lower().strip()
    
    print(f"Content after lower/strip: '{content_lower}'")
    print(f"Content lower length: {len(content_lower)}")
    print(f"Content lower repr: {repr(content_lower)}")
    
    # Debug logging
    print(f"Checking content for violations: '{content}' (lowercase: '{content_lower}')")
    
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
        print(f"Checking keyword '{keyword}' in '{content_lower}'")
        keyword_found = keyword in content_lower
        print(f"Keyword '{keyword}' found: {keyword_found}")
        if keyword_found:
            print(f"SEXUAL violation detected: '{keyword}' found in '{content}'")
            return True, 'SEXUAL'
    
    # Check for abuse - look for exact matches or word boundaries
    for keyword in abuse_keywords:
        # Check for exact match first
        exact_match = keyword == content_lower
        print(f"Checking exact match for '{keyword}' == '{content_lower}': {exact_match}")
        if exact_match:
            print(f"ABUSE violation detected: exact match '{keyword}'")
            return True, 'ABUSE'
        # Check for word boundaries to avoid partial matches
        word_boundary_match = f" {keyword} " in f" {content_lower} "
        print(f"Checking word boundary for '{keyword}' in '{content_lower}': {word_boundary_match}")
        if word_boundary_match:
            print(f"ABUSE violation detected: '{keyword}' found in '{content}'")
            return True, 'ABUSE'
        # Check if content starts or ends with the keyword
        starts_with = content_lower.startswith(f"{keyword} ")
        ends_with = content_lower.endswith(f" {keyword}")
        print(f"Checking starts/ends: starts='{keyword} ' in '{content_lower}': {starts_with}, ends='{content_lower}' ends with ' {keyword}': {ends_with}")
        if starts_with or ends_with:
            print(f"ABUSE violation detected: '{keyword}' found in '{content}'")
            return True, 'ABUSE'
            
    print("No obvious violations detected")
    return False, None

# Test the function
test_cases = [
    "send me nudes",
    "Send me nudes",
    "SEND ME NUDES",
    "send nudes",
    "Hello, how are you?"
]

print("Testing check_obvious_violations function:")
print("=" * 50)

for test_case in test_cases:
    print(f"\nTesting: '{test_case}'")
    result = check_obvious_violations(test_case)
    print(f"Result: {result}")

print("\n" + "=" * 50)
print("Test complete")