#!/usr/bin/env python3
"""
Script to verify that the backend is using the updated code with enhanced logging
"""

import sys
import os

# Add the project directory to the path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

# Import the function directly from the app module
try:
    # Try to import the app module
    import app
    
    print("=== BACKEND DEPLOYMENT VERIFICATION ===")
    print("Successfully imported app module")
    
    # Check if the enhanced check_obvious_violations function exists
    if hasattr(app, 'check_obvious_violations'):
        print("✓ check_obvious_violations function found")
        
        # Check the function's docstring to see if it has our enhancements
        func = app.check_obvious_violations
        docstring = func.__doc__ if func.__doc__ else ""
        
        if "=== CHECK_OBVIOUS_VIOLATIONS CALLED ===" in docstring:
            print("✓ Function has enhanced logging (new version)")
        else:
            print("? Function exists but may not have enhanced logging")
            
        # Test the function directly
        print("\n--- Testing function directly ---")
        try:
            result = func("send me nudes")
            print(f"Test result for 'send me nudes': {result}")
            
            if result[0] == True and result[1] == 'SEXUAL':
                print("✓ Function correctly identifies violation")
            else:
                print("✗ Function failed to identify violation")
                
        except Exception as e:
            print(f"✗ Error testing function: {e}")
    else:
        print("✗ check_obvious_violations function not found")
        
    # Check if the enhanced chat endpoint exists
    if hasattr(app, 'chat'):
        print("✓ chat endpoint function found")
    else:
        print("✗ chat endpoint function not found")
        
except Exception as e:
    print(f"Error importing app module: {e}")
    print("This might indicate the backend is not using the updated code")

print("\n=== VERIFICATION COMPLETE ===")