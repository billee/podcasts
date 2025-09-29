#!/usr/bin/env python3

import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

# Import the function from app.py
from app import check_obvious_violations

def test_violations():
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
    test_violations()