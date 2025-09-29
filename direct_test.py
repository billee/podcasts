#!/usr/bin/env python3

# Direct test of the function in app.py
import sys
import os

# Add the project directory to the path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# Set a dummy OpenAI API key to avoid initialization errors
os.environ['OPENAI_API_KEY'] = 'dummy-key'

try:
    # Import the function directly from app.py
    from app import check_obvious_violations
    
    # Test cases
    test_cases = [
        "send me nudes",
        "you are stupid", 
        "i hate you",
        "hello"
    ]
    
    print("Direct test of check_obvious_violations function:")
    print("=" * 50)
    
    for test_case in test_cases:
        result = check_obvious_violations(test_case)
        print(f"'{test_case}' -> {result}")
        
except Exception as e:
    print(f"Error: {e}")
    import traceback
    traceback.print_exc()