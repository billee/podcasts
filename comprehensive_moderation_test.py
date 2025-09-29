#!/usr/bin/env python3
"""
Comprehensive test for the moderation system to verify it correctly flags inappropriate content.
This test simulates the exact flow that should happen when a user sends "send me nudes".
"""

import json
import logging

# Set up logging to match the backend format
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

def check_obvious_violations(content):
    """
    Check for obvious violations that might be missed by OpenAI moderation
    Returns (is_violation, violation_type) tuple
    """
    content_lower = content.lower().strip()
    
    # Debug logging
    logger.info(f"Checking content for violations: '{content}' (lowercase: '{content_lower}')")
    
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
            logger.warning(f"SEXUAL violation detected: '{keyword}' found in '{content}'")
            return True, 'SEXUAL'
    
    # Check for abuse - look for exact matches or word boundaries
    for keyword in abuse_keywords:
        # Check for exact match first
        if keyword == content_lower:
            logger.warning(f"ABUSE violation detected: exact match '{keyword}'")
            return True, 'ABUSE'
        # Check for word boundaries to avoid partial matches
        if f" {keyword} " in f" {content_lower} ":
            logger.warning(f"ABUSE violation detected: '{keyword}' found in '{content}'")
            return True, 'ABUSE'
        # Check if content starts or ends with the keyword
        if content_lower.startswith(f"{keyword} ") or content_lower.endswith(f" {keyword}"):
            logger.warning(f"ABUSE violation detected: '{keyword}' found in '{content}'")
            return True, 'ABUSE'
            
    logger.info("No obvious violations detected")
    return False, None

def simulate_chat_endpoint(messages, user_id=None):
    """
    Simulate the /chat endpoint logic exactly as implemented in app.py
    """
    logger.info("=== CHAT ENDPOINT CALLED ===")
    logger.info(f"User ID: {user_id}")
    logger.info(f"Messages count: {len(messages) if messages else 0}")
    
    if not messages:
        logger.error("No messages provided")
        return {"error": "No messages provided"}, 400

    # Get the last user message for moderation
    user_messages = [msg for msg in messages if msg.get('role') == 'user']
    logger.info(f"User messages found: {len(user_messages)}")
    
    if user_messages:
        last_user_message = user_messages[-1].get('content', '')
        logger.info(f"Last user message: '{last_user_message}'")
        
        # First check for obvious violations
        is_obvious_violation, violation_type = check_obvious_violations(last_user_message)
        logger.info(f"Obvious violation check result: is_violation={is_obvious_violation}, type={violation_type}")
        
        if is_obvious_violation:
            logger.warning(f"⚠️ Message flagged by obvious violation check: {violation_type}")
            response_data = {
                "response": f"⚠️ Sorry, I can't continue because the message was flagged as {violation_type.lower()}.",
                "flagged": True,
                "categories": violation_type
            }
            logger.info(f"Returning flagged response: {json.dumps(response_data)}")
            return response_data, 200
        
        # Note: In the real implementation, this would call OpenAI's moderation API
        # For this test, we'll simulate that it also doesn't flag the content
        logger.info("Checking with OpenAI moderation API (simulated)")
        # Simulate OpenAI moderation not flagging the content
        is_flagged = False
        categories = None
        logger.info(f"OpenAI moderation result: is_flagged={is_flagged}, categories={categories}")
        
        if is_flagged:
            logger.warning(f"⚠️ Message flagged by OpenAI moderation: {categories}")
            response_data = {
                "response": "⚠️ Sorry, I can't continue because the message was flagged as inappropriate.",
                "flagged": True,
                "categories": str(categories) if categories else "Unknown"
            }
            logger.info(f"Returning flagged response: {json.dumps(response_data)}")
            return response_data, 200

    # If we get here, no moderation flagged the content
    # In the real implementation, this would call the LLM
    logger.info("No moderation flags - would call LLM in real implementation")
    normal_response = "Bakit ganyan? Parang hindi naman tama yan, di ba?"
    response_data = {"response": normal_response}
    logger.info(f"Returning normal response: {json.dumps(response_data)}")
    return response_data, 200

def test_moderation_system():
    """Test the moderation system with the exact scenario from the logs"""
    print("=" * 80)
    print("COMPREHENSIVE MODERATION SYSTEM TEST")
    print("=" * 80)
    
    # Test case from the logs
    test_message = "send me nudes"
    print(f"\nTesting with message: '{test_message}'")
    print("-" * 40)
    
    # Simulate the exact message structure from the frontend
    messages = [
        {
            "role": "user",
            "content": test_message,
            "senderName": "TestUser"
        }
    ]
    
    # Test the violation detection function directly
    print("1. Testing check_obvious_violations function:")
    is_violation, violation_type = check_obvious_violations(test_message)
    print(f"   Result: is_violation={is_violation}, violation_type={violation_type}")
    
    if is_violation:
        expected_response = f"⚠️ Sorry, I can't continue because the message was flagged as {violation_type.lower()}."
        print(f"   Expected response: '{expected_response}'")
    else:
        print("   ERROR: Should have detected violation!")
    
    # Test the full chat endpoint simulation
    print("\n2. Testing full chat endpoint simulation:")
    response_data, status_code = simulate_chat_endpoint(messages, "test_user_id")
    print(f"   Status code: {status_code}")
    print(f"   Response: {json.dumps(response_data, indent=2)}")
    
    # Check if the response is correctly flagged
    if status_code == 200 and "response" in response_data:
        response_text = response_data["response"]
        is_flagged = "Sorry, I can't continue" in response_text
        print(f"   Is flagged response: {is_flagged}")
        
        if is_flagged and "sexual" in response_text.lower():
            print("   ✓ CORRECT: Message was properly flagged as sexual content")
        elif is_flagged:
            print("   ✓ Message was flagged, but with different violation type")
        else:
            print("   ✗ ERROR: Message was not flagged when it should have been!")
    
    # Test with normal content
    print("\n3. Testing with normal content:")
    normal_message = "Hello, how are you?"
    print(f"   Testing with message: '{normal_message}'")
    
    is_violation, violation_type = check_obvious_violations(normal_message)
    print(f"   Result: is_violation={is_violation}, violation_type={violation_type}")
    
    normal_messages = [
        {
            "role": "user",
            "content": normal_message,
            "senderName": "TestUser"
        }
    ]
    
    response_data, status_code = simulate_chat_endpoint(normal_messages, "test_user_id")
    print(f"   Status code: {status_code}")
    response_text = response_data.get("response", "") if status_code == 200 else ""
    is_flagged = "Sorry, I can't continue" in response_text
    print(f"   Is flagged response: {is_flagged}")
    
    if not is_flagged:
        print("   ✓ CORRECT: Normal message was not flagged")
    else:
        print("   ✗ ERROR: Normal message was incorrectly flagged!")
    
    print("\n" + "=" * 80)
    print("TEST COMPLETE")
    print("=" * 80)

if __name__ == "__main__":
    test_moderation_system()