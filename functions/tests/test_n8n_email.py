import requests
import json

# --- Configuration ---
# IMPORTANT: Replace this with the actual URL of your n8n webhook node.
# You will get this URL from the Webhook node in your n8n workflow after you set it up.
N8N_WEBHOOK_URL = "https://billee.app.n8n.cloud/webhook/07b3fa5e-0d2c-41fc-bc80-ded9b250f377"

# Email details to be sent via n8n
email_data = {
    "to": "twilly.t@gmail.com",  # Replace with the recipient's email address
    "subject": "Hello from Python via n8n!",
    "body": "This is a test email sent from a Python script, triggered by an n8n workflow. How cool is that?",
    # You can add more fields here if your n8n workflow expects them,
    # e.g., "from_name": "My App", "attachments": ["url_to_file.pdf"]
}

# --- Send the request ---
def send_email_via_n8n(webhook_url, data):
    """
    Sends a POST request to the specified n8n webhook URL with the given data.
    """
    headers = {
        "Content-Type": "application/json"
    }
    try:
        print(f"Attempting to send data to n8n webhook: {webhook_url}")
        response = requests.post(webhook_url, headers=headers, data=json.dumps(data))

        # Check if the request was successful (status code 2xx)
        response.raise_for_status()

        print("Request successful!")
        print(f"n8n Response Status Code: {response.status_code}")
        print(f"n8n Response Body: {response.text}")

    except requests.exceptions.RequestException as e:
        print(f"An error occurred while sending the request: {e}")
        if hasattr(e, 'response') and e.response is not None:
            print(f"Error Response Status Code: {e.response.status_code}")
            print(f"Error Response Body: {e.response.text}")
    except Exception as e:
        print(f"An unexpected error occurred: {e}")

if __name__ == "__main__":
    # Remove this if condition entirely, or change it to check for an empty string
    # if N8N_WEBHOOK_URL == "YOUR_N8N_WEBHOOK_URL_HERE": # This was the original, correct check
    #     print("ERROR: Please update 'N8N_WEBHOOK_URL' with your actual n8n webhook URL.")
    #     print("Follow the steps below to set up your n8n workflow and get the URL.")
    # else:
    send_email_via_n8n(N8N_WEBHOOK_URL, email_data)

