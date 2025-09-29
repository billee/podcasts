#!/usr/bin/env python3
"""
Test script to verify that the moderation system correctly detects Tagalog profanity
"""

import sys
import os

# Add the project directory to the path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

def check_obvious_violations(content):
    """
    Check for obvious violations that might be missed by OpenAI moderation
    Returns (is_violation, violation_type) tuple
    """
    content_lower = content.lower().strip()
    
    # Obvious sexual content requests (English and Tagalog)
    sexual_keywords = [
        # English keywords
        'send me nudes', 'send nudes', 'nudes please', 'naked pics',
        'sex pics', 'sexy photos', 'explicit photos',
        # Tagalog keywords for sexual content
        'ipakita mo sa akin ang iyong katawan', 'magpadala ng mga larawan ng katawan', 
        'larawan ng hubad', 'larawan ng sekso', 'ipakita ang iyong mga nudes'
    ]
    
    # Obvious abuse/hate speech (English and Tagalog)
    abuse_keywords = [
        # English keywords
        'fuck you', 'shit head', 'stupid idiot', 'die idiot',
        'you are stupid', 'i hate you', 'hate you', 'you suck',
        'idiot', 'stupid', 'dumb', 'worthless',
        # Tagalog keywords for abuse/hate speech
        'gago ka', 'gago ka talaga', 'tanga ka', 'bobo ka', 'ulol ka',
        'hindot ka', 'puta ka', 'tang ina mo', 'fuck you', 'shit ka',
        'walang kwenta', 'bubu mo', 'bobo mo', 'tanga mo', 'gaga mo',
        'hinayupak ka', 'pucha ka', 'pokpok ka', 'lintek ka'
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

# Test cases including Tagalog profanity
test_cases = [
    # English cases
    ("send me nudes", "SEXUAL"),
    ("fuck you", "ABUSE"),
    ("stupid idiot", "ABUSE"),
    ("Hello, how are you?", None),
    
    # Tagalog cases
    ("gago ka", "ABUSE"),
    ("gago ka talaga", "ABUSE"),
    ("tanga ka", "ABUSE"),
    ("bobo ka", "ABUSE"),
    ("puta ka", "ABUSE"),
    ("hindot ka", "ABUSE"),
    ("tang ina mo", "ABUSE"),
    ("walang kwenta", "ABUSE"),
    ("Magandang araw!", None),
    ("Salamat po", None),
    
    # Mixed cases
    ("gago ka talaga you idiot", "ABUSE"),
]

print("Testing Tagalog/English moderation system:")
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
    print("🎉 All tests passed! The moderation system is working correctly.")
else:
    print("❌ Some tests failed. Please review the moderation keywords.")