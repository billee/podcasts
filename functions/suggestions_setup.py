import os
import json
from typing import List, Dict, Any

from suggestion_extractor import SuggestionExtractor
from firestore_manager import FirestoreManager
from data_source_reader import DataSourceReader


class SuggestionsManager:
    def __init__(self):
        self.suggestion_extractor = SuggestionExtractor()
        self.firestore_manager = FirestoreManager()
        self.data_reader = DataSourceReader()
        print("✅ SuggestionsManager initialized with all dependencies")

    def extract_and_replace_suggestions(self):
        """
        Main function: Extract suggestions from all data sources by combining text
        from all files and replacing Firestore collection.
        """
        print("\n🚀 Starting suggestions extraction and replacement process...")

        print("\n=== READING DATA SOURCES INTO SINGLE STRING ===")
        all_combined_text = self.data_reader.read_all_files_into_single_string()

        if not all_combined_text:
            print("No content found in data sources. Exiting extraction process.")
            return

        print('all_combined_text.........')
        print(all_combined_text)
        # quit()


        print("\n=== EXTRACTING SUGGESTIONS FROM COMBINED TEXT ===")
        # Pass the single combined string to the suggestion extractor
        extracted_suggestions = self.suggestion_extractor.extract_suggestions_from_combined_text(all_combined_text)

        if not extracted_suggestions:
            print("No suggestions extracted. Exiting process.")
            return

        print(f"\n🎉 Successfully extracted {len(extracted_suggestions)} new suggestions.")

        print(extracted_suggestions)
        # quit()

        print("\n=== UPDATING FIRESTORE ===")
        current_suggestions_count = self.firestore_manager.get_suggestions_count()
        print(f"Current number of suggestions in Firestore: {current_suggestions_count}")

        # print("Clearing existing suggestions in Firestore...")
        # self.firestore_manager.clear_existing_suggestions()
        # print("Existing suggestions cleared.")

        print("Adding new suggestions to Firestore...")
        self.firestore_manager.batch_add_suggestions(extracted_suggestions)
        print("New suggestions added to Firestore.")

        final_suggestions_count = self.firestore_manager.get_suggestions_count()
        print(f"Final number of suggestions in Firestore: {final_suggestions_count}")
        print("\n✅ Suggestions extraction and Firestore update process completed.")


    def validate_dependencies(self):
        """Validates that all necessary components and configurations are in place."""
        print("\n=== VALIDATING DEPENDENCIES ===")
        try:
            # Check for OpenAI API key
            openai_api_key = os.getenv('OPENAI_API_KEY')
            if not openai_api_key:
                print("❌ OPENAI_API_KEY environment variable not set.")
                print("   Please set it to your OpenAI API key.")
            else:
                print("✅ OpenAI API Key found.")

            # Check for Firebase credentials path
            firebase_credentials_path = os.getenv('FIREBASE_CREDENTIALS_PATH', 'C:/Users/sanme/AndroidStudioProjects/kapwa_companion/serviceAccountKey.json')
            if not os.path.exists(firebase_credentials_path):
                print(f"❌ Firebase credentials file not found at: {firebase_credentials_path}")
                print("   Please ensure 'serviceAccountKey.json' is in the correct path or FIREBASE_CREDENTIALS_PATH is set.")
            else:
                print(f"✅ Firebase credentials file found at: {firebase_credentials_path}")

            # Check for data_sources directory
            data_sources_path = self.data_reader.data_sources_path
            if not os.path.exists(data_sources_path):
                print(f"❌ Data sources directory not found at: {data_sources_path}")
                print("   Please create a 'data_sources' directory in the same location as this script.")
            else:
                print(f"✅ Data sources directory found at: {data_sources_path}")
                # Check if it contains any supported files directly
                found_files = False
                for filename in os.listdir(data_sources_path):
                    if os.path.isfile(os.path.join(data_sources_path, filename)):
                        ext = os.path.splitext(filename)[1].lower()
                        if ext in ['.txt', '.json', '.pdf']:
                            found_files = True
                            break
                if found_files:
                    print("✅ Supported files found directly in data_sources directory.")
                else:
                    print("⚠️ No supported .txt, .json, or .pdf files found directly in the data_sources directory.")
                    print("   Ensure your data files are placed directly inside './data_sources'.")

            # Try to initialize managers (basic check)
            try:
                FirestoreManager()
                print("✅ FirestoreManager initialized successfully (basic check).")
            except Exception as e:
                print(f"❌ FirestoreManager initialization failed: {e}")
                print("   Please check your Firebase credentials and project setup.")

            try:
                SuggestionExtractor()
                print("✅ SuggestionExtractor initialized successfully (basic check).")
            except Exception as e:
                print(f"❌ SuggestionExtractor initialization failed: {e}")
                print("   Please ensure your OPENAI_API_KEY is valid.")

            print("\n✅ Dependency validation complete. Please review any '❌' messages above.")

        except Exception as e:
            print(f"❌ An error occurred during dependency validation: {e}")


    def show_firestore_status(self):
        """Displays the current number of suggestions in Firestore."""
        print("\n=== FIRESTORE STATUS ===")
        try:
            count = self.firestore_manager.get_suggestions_count()
            print(f"Number of suggestions currently in Firestore: {count}")
        except Exception as e:
            print(f"❌ Error getting Firestore status: {e}")
            print("   Please ensure your Firebase credentials and network connection are correct.")

    def show_data_sources_info(self):
        """Displays information about the data sources directory and files."""
        print("\n=== DATA SOURCES INFORMATION ===")
        self.data_reader.print_directory_structure()

    def run_complete_setup(self):
        """Runs validation followed by extraction and Firestore update."""
        print("\n=== RUNNING COMPLETE SETUP (VALIDATE + EXTRACT) ===")
        self.validate_dependencies()
        print("\nContinuing with extraction and update (if validation passed)...")
        self.extract_and_replace_suggestions()
        print("\n✅ Complete setup process finished.")


def show_interactive_menu():
    """Shows an interactive menu for the user."""
    manager = SuggestionsManager()
    while True:
        print("\n--- Suggestions Setup Menu ---")
        print("1. Extract suggestions and update Firestore ('extract' or 'run')")
        print("2. Validate dependencies ('validate' or 'test')")
        print("3. Check Firestore status ('status')")
        print("4. Show data sources information ('info')")
        print("5. Run complete setup (validate + extract) ('complete' or 'all')")
        print("6. Exit ('exit' or 'quit')")
        print("------------------------------")

        choice = input("Enter command or number: ").strip().lower()

        if choice in ('1', 'extract', 'run'):
            manager.extract_and_replace_suggestions()
        elif choice in ('2', 'validate', 'test'):
            manager.validate_dependencies()
        elif choice in ('3', 'status'):
            manager.show_firestore_status()
        elif choice in ('4', 'info'):
            manager.show_data_sources_info()
        elif choice in ('5', 'complete', 'all'):
            manager.run_complete_setup()
        elif choice in ('6', 'exit', 'quit'):
            print("Exiting.")
            break
        else:
            print("Invalid choice. Please try again.")

def main():
    """Main function to handle command-line arguments or launch interactive menu."""
    manager = SuggestionsManager()
    import sys
    if len(sys.argv) > 1:
        operation = sys.argv[1].lower()
        if operation == "extract" or operation == "run":
            print("Running extraction and Firestore update...")
            manager.extract_and_replace_suggestions()

        elif operation == "validate" or operation == "test":
            print("Validating dependencies...")
            manager.validate_dependencies()

        elif operation == "status":
            print("Checking Firestore status...")
            manager.show_firestore_status()

        elif operation == "info":
            print("Showing data sources information...")
            manager.show_data_sources_info()

        elif operation == "complete" or operation == "all":
            print("Running complete setup with validation...")
            manager.run_complete_setup()

        elif operation == "interactive" or operation == "menu":
            print("Starting interactive mode...")
            show_interactive_menu()

        else:
            print("Usage: python suggestions_setup.py [command]")
            print("\nAvailable commands:")
            print("  extract     - Extract suggestions and update Firestore")
            print("  validate    - Validate all dependencies")
            print("  status      - Check current Firestore status")
            print("  info        - Show data sources information")
            print("  complete    - Run complete setup with validation")
            print("  interactive - Start interactive menu")
            print("  (no args)   - Start interactive menu (default)")

    else:
        print("No command-line arguments provided. Starting interactive mode (default)...")
        show_interactive_menu()

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\n⏹️ Process interrupted by user.")
    except Exception as e:
        print(f"\n❌ Fatal error in suggestions setup: {e}")
        import traceback
        traceback.print_exc()