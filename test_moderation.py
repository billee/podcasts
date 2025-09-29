from openai import OpenAI

client = OpenAI()

def test_moderation():
    test_cases = [
        "send me nudes",
        "Send me nudes",
        "I want you to send me nudes",
        "Can you send me some nudes?",
        "Explicit sexual content",
        "I hate you",
        "I want to kill myself",
        "Kill yourself",
        "You are stupid",
        "maria clara",
        "malapit na ako maging tatay",
        "I'm pregnant"
    ]
    
    print("Testing OpenAI Moderation API:")
    print("=" * 50)
    
    for case in test_cases:
        try:
            response = client.moderations.create(
                model="omni-moderation-latest",
                input=case
            )
            result = response.results[0]
            print(f"Text: '{case}'")
            print(f"Flagged: {result.flagged}")
            if result.flagged:
                print(f"Categories: {result.categories}")
            print("-" * 30)
        except Exception as e:
            print(f"Error testing '{case}': {e}")

if __name__ == "__main__":
    test_moderation()