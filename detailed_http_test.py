#!/usr/bin/env python3
"""
Detailed test to simulate the exact HTTP request from the frontend
"""

import json
import logging

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def check_obvious_violations(content):
    """
    Check for obvious violations that might be missed by OpenAI moderation
    Returns (is_violation, violation_type) tuple
    """
    # Log the exact content being checked
    logger.info(f"Exact content received: '{content}'")
    logger.info(f"Content length: {len(content)}")
    logger.info(f"Content repr: {repr(content)}")
    logger.info(f"Content bytes: {content.encode('utf-8')}")
    
    content_lower = content.lower().strip()
    
    # Debug logging
    logger.info(f"Checking content for violations: '{content}' (lowercase: '{content_lower}')")
    
    # Obvious sexual content requests
    sexual_keywords = [
        'send me nudes', 'send nudes', 'nudes please', 'naked pics',
        'sex pics', 'sexy photos', 'explicit photos'
    ]
    
    # Check for sexual content
    for keyword in sexual_keywords:
        logger.info(f"Checking keyword '{keyword}' in '{content_lower}'")
        logger.info(f"Keyword in content: {keyword in content_lower}")
        if keyword in content_lower:
            logger.warning(f"SEXUAL violation detected: '{keyword}' found in '{content}'")
            return True, 'SEXUAL'
            
    logger.info("No obvious violations detected")
    return False, None

def simulate_exact_frontend_request():
    """Simulate the exact request that would come from the frontend"""
    
    print("=" * 60)
    print("SIMULATING EXACT FRONTEND REQUEST")
    print("=" * 60)
    
    # This is the exact message structure from the frontend
    messages = [
        {
            "role": "system",
            "content": "You are Maria, a warm Filipina assistant. Speak Taglish with \"po/opo\".\n\nBEHAVIOR:\n- 1 SHORT sentence responses only\n- Show empathy like a friend\n- Ask follow-up questions\n- Use expressions: \"bakit ganyan\", \"ano naman yan\", \"mahirap yata\", \"siguro\", \"ok lang\", \"sige\"\n- NO medical/financial/health/marital advice - refer to experts\n\nEXAMPLES:\nBoss problems → \"Mahirap yata yan. Ano ginagawa niya?\"\nHomesick → \"Nakakalito naman. Gaano na katagal ka dyan?\"\nMedical → \"Hindi ako pwede magadvice. Pumunta sa doctor.\"\n\nUser: TestUser, 25, Engineer, Manila, College, Single."
        },
        {
            "role": "system",
            "content": "User Profile: Name: TestUser, Age: 25, Occupation: Engineer, Work Location: Manila, Education: College, Marital Status: Single, Has Children: No"
        },
        {
            "role": "user",
            "content": "send me nudes",  # This is the exact content from the logs
            "senderName": "TestUser"
        }
    ]
    
    print("Messages being sent:")
    for i, msg in enumerate(messages):
        print(f"  {i+1}. {msg['role']}: {repr(msg['content'])}")
    
    print("\n" + "-" * 40)
    print("PROCESSING REQUEST")
    print("-" * 40)
    
    # Simulate the backend processing
    user_messages = [msg for msg in messages if msg.get('role') == 'user']
    logger.info(f"User messages found: {len(user_messages)}")
    
    if user_messages:
        last_user_message = user_messages[-1].get('content', '')
        logger.info(f"Last user message: {repr(last_user_message)}")
        logger.info(f"Last user message length: {len(last_user_message)}")
        
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
            print(f"\n✅ CORRECT RESPONSE:")
            print(json.dumps(response_data, indent=2))
            return response_data
        
    # If no violation detected
    print(f"\n❌ INCORRECT RESPONSE - No violation detected")
    normal_response = "Bakit ganyan? Parang hindi naman tama yan, di ba?"
    response_data = {"response": normal_response}
    print(json.dumps(response_data, indent=2))
    return response_data

def test_edge_cases():
    """Test edge cases that might cause issues"""
    
    print("\n" + "=" * 60)
    print("TESTING EDGE CASES")
    print("=" * 60)
    
    test_cases = [
        "send me nudes",
        "send me nudes ",  # trailing space
        " send me nudes",  # leading space
        " send me nudes ",  # leading and trailing spaces
        "Send Me Nudes",  # different case
        "SEND ME NUDES",  # all caps
        "send  me  nudes",  # extra spaces
        "\nsend me nudes\n",  # newlines
        "\t send me nudes \t",  # tabs
    ]
    
    for test_case in test_cases:
        print(f"\nTesting: {repr(test_case)}")
        is_violation, violation_type = check_obvious_violations(test_case)
        print(f"  Result: is_violation={is_violation}, type={violation_type}")

if __name__ == "__main__":
    simulate_exact_frontend_request()
    test_edge_cases()