import openai
import os
from dotenv import load_dotenv
from typing import List, Dict, Any
import json
from datetime import datetime

load_dotenv()

class SuggestionExtractor:
    def __init__(self, api_key: str = None):
        self.client = openai.OpenAI(api_key=api_key or os.getenv('OPENAI_API_KEY'))

    def _process_llm_response(self, raw_content: str, context_label: str) -> List[Dict]:
        """Strips markdown fences and parses JSON, adding generic metadata."""
        print(f"DEBUG: Raw OpenAI response for {context_label}:")
        print(raw_content)

        # --- Strip markdown code block fences ---
        if raw_content.startswith("```json"):
            raw_content = raw_content[len("```json"):].strip()
        if raw_content.endswith("```"):
            raw_content = raw_content[:-len("```")].strip()

        try:
            suggestions = json.loads(raw_content)
        except json.JSONDecodeError as e:
            print(f"❌ JSON decoding error for {context_label}: {e}")
            print(f"Raw content that caused error: {raw_content[:500]}...") # Print first 500 chars for debugging
            return []

        extracted_suggestions_with_metadata = []
        current_timestamp = self._get_current_timestamp()
        for suggestion in suggestions:
            # Ensure each suggestion is a dictionary and has a 'suggestion' key
            if isinstance(suggestion, dict) and 'suggestion' in suggestion:
                # Add generic metadata
                suggestion['extracted_at'] = current_timestamp
                # For combined text, source and file_type are generalized
                suggestion['source'] = "Combined Data Sources"
                suggestion['file_type'] = "mixed" # Or 'text/plain' or similar

                extracted_suggestions_with_metadata.append(suggestion)
            else:
                print(f"⚠️ Skipping malformed suggestion: {suggestion}")


        # Deduplicate suggestions based on the 'suggestion' text, while preserving other fields from the first occurrence
        seen_suggestions = {}
        unique_suggestions = []
        for s in extracted_suggestions_with_metadata:
            suggestion_text_lower = s.get('suggestion', '').lower().strip()
            if suggestion_text_lower and suggestion_text_lower not in seen_suggestions:
                seen_suggestions[suggestion_text_lower] = True
                unique_suggestions.append(s)
            elif not suggestion_text_lower:
                print(f"⚠️ Skipping suggestion with empty text: {s}")


        return unique_suggestions

    def extract_suggestions_from_combined_text(self, combined_text: str) -> List[Dict]:
        """
        Extracts sensible, non-duplicate 5-word suggestions from a single,
        large combined text string using LLM.
        """
        print("Calling LLM to extract suggestions from combined text...")

        prompt = f"""
        You are an expert advisor on Overseas Filipino Worker status. From the following combined text, extract practical, actionable advice.
        Each piece of advice must be a standalone suggestion, around 5 words in length, and expressed as a concise phrase.
        Ensure there are no duplicate suggestions.
        Focus on providing advice relevant to the context of the text, which seems to be related to Overseas Filipino Workers (OFWs).

        Respond ONLY with a JSON array, where each element is an object like this:
        {{"suggestion": "Your concise 5-word suggestion here"}}

        Combined Text:
        {combined_text}
        """

        try:
            response = self.client.chat.completions.create(
                model="gpt-4o-mini",
                messages=[
                    {"role": "system", "content": "You are an expert advisor. Extract practical, actionable advice. Respond ONLY with a JSON array."},
                    {"role": "user", "content": prompt}
                ],
                temperature=0.3, # Keep temperature low for more focused, less creative suggestions
                max_tokens=4000 # Adjust based on expected output size
            )
            suggestions = self._process_llm_response(response.choices[0].message.content, "combined text extraction")
            return suggestions
        except Exception as e:
            print(f"Error extracting suggestions from combined content: {e}")
            return []

    def _get_current_timestamp(self):
        return datetime.now().isoformat()
