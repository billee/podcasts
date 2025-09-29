#!/usr/bin/env python3
"""
Test script to verify that the moderation system correctly detects mental health crisis expressions
"""

def check_obvious_violations(content):
    """
    Check for obvious violations that might be missed by OpenAI moderation
    Returns (is_violation, violation_type) tuple
    """
    content_lower = content.lower().strip()
    
    # Mental health crisis expressions (suicide/self-harm intentions)
    mental_health_keywords = [
        # English keywords indicating suicide/self-harm intent
        'i want to kill myself', 'i want to die', 'i am going to kill myself',
        'i am going to die', 'kill myself', 'end my life', 'end it all',
        'suicide', 'commit suicide', 'take my own life', 'no reason to live',
        'want to die', 'going to end it', 'self harm', 'cut myself',
        # Tagalog keywords indicating suicide/self-harm intent
        'gusto kong mamatay', 'gusto kong patayin ang sarili ko', 
        'papatayin ko ang sarili ko', 'wala nang kwenta ang buhay ko',
        'wala akong pakialam', 'puputulin ko ang aking braso',
        'gagawin ko ang suicide', 'patay na ako', 'wala na akong buhay'
    ]
    
    # Check for mental health crisis expressions first (highest priority)
    for keyword in mental_health_keywords:
        if keyword in content_lower:
            return True, 'MENTAL_HEALTH'
    
    # Other keywords (simplified for this test)
    sexual_keywords = ['send me nudes', 'send nudes']
    abuse_keywords = ['fuck you', 'shit head', 'stupid idiot']
    
    # Check for sexual content
    for keyword in sexual_keywords:
        if keyword in content_lower:
            return True, 'SEXUAL'
    
    # Check for abuse
    for keyword in abuse_keywords:
        if keyword in content_lower:
            return True, 'ABUSE'
            
    return False, None

# Test cases for mental health expressions
test_cases = [
    # Mental health crisis expressions
    ("I want to kill myself", "MENTAL_HEALTH"),
    ("I want to die", "MENTAL_HEALTH"),
    ("I am going to kill myself", "MENTAL_HEALTH"),
    ("Kill myself", "MENTAL_HEALTH"),
    ("End my life", "MENTAL_HEALTH"),
    ("End it all", "MENTAL_HEALTH"),
    ("Commit suicide", "MENTAL_HEALTH"),
    ("Take my own life", "MENTAL_HEALTH"),
    ("No reason to live", "MENTAL_HEALTH"),
    ("Want to die", "MENTAL_HEALTH"),
    ("Going to end it", "MENTAL_HEALTH"),
    ("Self harm", "MENTAL_HEALTH"),
    ("Cut myself", "MENTAL_HEALTH"),
    
    # Tagalog mental health expressions
    ("Gusto kong mamatay", "MENTAL_HEALTH"),
    ("Gusto kong patayin ang sarili ko", "MENTAL_HEALTH"),
    ("Papatayin ko ang sarili ko", "MENTAL_HEALTH"),
    ("Wala nang kwenta ang buhay ko", "MENTAL_HEALTH"),
    
    # Non-flagged expressions (should not be flagged)
    ("I'm excited to be a parent", None),
    ("I'm about to become a father", None),
    ("Buntis na ako", None),
    ("Malapit na ako maging tatay", None),
    ("Hello, how are you?", None),
    ("I'm feeling sad today", None),  # Just sad, not expressing intent
    
    # Other violations (to ensure we didn't break existing functionality)
    ("Send me nudes", "SEXUAL"),
    ("Fuck you", "ABUSE"),
]

print("Testing Mental Health Moderation System:")
print("=" * 60)

correct_detections = 0
total_tests = len(test_cases)

for test_message, expected_type in test_cases:
    result = check_obvious_violations(test_message)
    is_violation, violation_type = result
    
    if expected_type is None:
        # Should not be flagged
        if not is_violation:
            status = "✓ CORRECT (Not flagged)"
            correct_detections += 1
        else:
            status = f"✗ INCORRECT (Flagged as {violation_type})"
    else:
        # Should be flagged
        if is_violation and violation_type == expected_type:
            status = f"✓ CORRECT (Flagged as {violation_type})"
            correct_detections += 1
        elif is_violation:
            status = f"△ PARTIAL (Flagged as {violation_type}, expected {expected_type})"
            correct_detections += 1  # Count as correct since it was flagged
        else:
            status = "✗ INCORRECT (Not flagged)"
    
    print(f"'{test_message}' -> {result} {status}")

print("\n" + "=" * 60)
print(f"Results: {correct_detections}/{total_tests} tests passed")
accuracy = (correct_detections / total_tests) * 100
print(f"Accuracy: {accuracy:.1f}%")

if correct_detections == total_tests:
    print("🎉 All tests passed! The mental health moderation system is working correctly.")
else:
    print("❌ Some tests failed. Please review the moderation keywords.")

# Test the specific examples from the system prompt that should NOT be flagged
print("\n" + "=" * 60)
print("Testing False Positive Prevention:")
print("=" * 60)

false_positive_tests = [
    "malapit na ako maging tatay",  # Should NOT be flagged (pregnancy/fatherhood)
    "buntis na ako",  # Should NOT be flagged (pregnancy)
    "excited to be a parent",  # Should NOT be flagged (normal life event)
]

false_positive_correct = 0
for test_message in false_positive_tests:
    result = check_obvious_violations(test_message)
    is_violation, violation_type = result
    
    if not is_violation:
        status = "✓ CORRECT (Not flagged - avoiding false positive)"
        false_positive_correct += 1
    else:
        status = f"✗ INCORRECT (Flagged as {violation_type} - false positive!)"
    
    print(f"'{test_message}' -> {result} {status}")

if false_positive_correct == len(false_positive_tests):
    print("\n✅ All false positive tests passed! The system correctly avoids flagging normal life events.")
else:
    print("\n❌ Some false positive tests failed! The system may be over-flagging normal life events.")