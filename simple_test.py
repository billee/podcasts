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

def test_function():
    test_cases = [
        ("send me nudes", True, "SEXUAL"),
        ("you are stupid", True, "ABUSE"),
        ("i hate you", True, "ABUSE"),
        ("hello", False, None),
        ("how are you", False, None),
        ("idiot", True, "ABUSE"),
        ("stupid", True, "ABUSE"),
        ("this is stupid", True, "ABUSE"),
        ("you idiot", True, "ABUSE"),
        ("malapit na ako maging tatay", False, None),
        ("maria clara", False, None)
    ]
    
    print("Testing obvious violation detection:")
    print("=" * 50)
    
    all_passed = True
    for test_input, expected_flagged, expected_type in test_cases:
        is_flagged, violation_type = check_obvious_violations(test_input)
        status = "PASS" if (is_flagged == expected_flagged and 
                           (not expected_flagged or violation_type == expected_type)) else "FAIL"
        
        if status == "FAIL":
            all_passed = False
            
        print(f"Input: '{test_input}'")
        print(f"Expected: {expected_flagged} ({expected_type})")
        print(f"Got: {is_flagged} ({violation_type})")
        print(f"Status: {status}")
        print("-" * 30)
    
    print(f"\nOverall result: {'ALL TESTS PASSED' if all_passed else 'SOME TESTS FAILED'}")
    return all_passed

if __name__ == "__main__":
    test_function()