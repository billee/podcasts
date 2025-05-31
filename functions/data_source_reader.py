import os
import json
import PyPDF2
from typing import Dict, Any, List

class DataSourceReader:
    def __init__(self, data_sources_path: str = "./data_sources"):
        self.data_sources_path = data_sources_path

    def read_all_files_into_single_string(self) -> str:
        """
        Read all supported files from the data_sources directory (no subdirectories).
        Concatenates all text content into a single string,
        with '%%' as a delimiter between the content of each file.
        Supported formats: .txt, .json, .pdf
        This method is primarily for the suggestions feature.
        """
        all_string = ""

        if not os.path.exists(self.data_sources_path):
            print(f"Data sources path '{self.data_sources_path}' does not exist.")
            return all_string

        if not os.path.isdir(self.data_sources_path):
            print(f"Path '{self.data_sources_path}' is not a directory.")
            return all_string

        print(f"🚀 Reading files from: {self.data_sources_path}")

        try:
            for filename in os.listdir(self.data_sources_path):
                file_path = os.path.join(self.data_sources_path, filename)

                if os.path.isfile(file_path):
                    file_extension = os.path.splitext(filename)[1].lower()
                    content = ""

                    if file_extension == '.txt':
                        try:
                            with open(file_path, 'r', encoding='utf-8') as f:
                                content = f.read()
                            print(f"  ✅ Read TXT: {filename}")
                        except Exception as e:
                            print(f"  ❌ Error reading TXT file {filename}: {e}")
                            continue
                    elif file_extension == '.json':
                        try:
                            with open(file_path, 'r', encoding='utf-8') as f:
                                json_data = json.load(f)
                                content = json.dumps(json_data, indent=2) # Convert JSON object to string
                            print(f"  ✅ Read JSON: {filename}")
                        except Exception as e:
                            print(f"  ❌ Error reading JSON file {filename}: {e}")
                            continue
                    elif file_extension == '.pdf':
                        try:
                            pdf_file_obj = open(file_path, 'rb')
                            pdf_reader = PyPDF2.PdfReader(pdf_file_obj)
                            for page_num in range(len(pdf_reader.pages)):
                                page_obj = pdf_reader.pages[page_num]
                                content += page_obj.extract_text() or "" # Handle potential None from extract_text
                            pdf_file_obj.close()
                            print(f"  ✅ Read PDF: {filename}")
                        except Exception as e:
                            print(f"  ❌ Error reading PDF file {filename}: {e}")
                            continue
                    else:
                        print(f"   skipping unsupported file: {filename}")
                        continue

                    if content:
                        all_string += content + "%%"
                        print(f"    Added content from {filename} to all_string.")

        except Exception as e:
            print(f"❌ An error occurred while reading files: {e}")

        print(f"\n🎉 Finished reading all files. Total content length: {len(all_string)} characters.")
        return all_string

    def read_all_files(self) -> List[Dict[str, Any]]:
        """
        Read all supported files from the data_sources directory (no subdirectories).
        Returns a list of dictionaries, where each dictionary contains
        'content', 'filename', and 'file_type'.
        Supported formats: .txt, .json, .pdf
        This method is for populating vector databases to retain metadata.
        """
        files_data = []

        if not os.path.exists(self.data_sources_path):
            print(f"Data sources path '{self.data_sources_path}' does not exist.")
            return files_data

        if not os.path.isdir(self.data_sources_path):
            print(f"Path '{self.data_sources_path}' is not a directory.")
            return files_data

        print(f"🚀 Reading individual files from: {self.data_sources_path}")

        try:
            for filename in os.listdir(self.data_sources_path):
                file_path = os.path.join(self.data_sources_path, filename)

                if os.path.isfile(file_path):
                    file_extension = os.path.splitext(filename)[1].lower()
                    content = ""
                    file_type = ""

                    if file_extension == '.txt':
                        try:
                            with open(file_path, 'r', encoding='utf-8') as f:
                                content = f.read()
                            file_type = "txt"
                            print(f"  ✅ Read TXT: {filename}")
                        except Exception as e:
                            print(f"  ❌ Error reading TXT file {filename}: {e}")
                            continue
                    elif file_extension == '.json':
                        try:
                            with open(file_path, 'r', encoding='utf-8') as f:
                                json_data = json.load(f)
                                content = json.dumps(json_data, indent=2) # Convert JSON object to string
                            file_type = "json"
                            print(f"  ✅ Read JSON: {filename}")
                        except Exception as e:
                            print(f"  ❌ Error reading JSON file {filename}: {e}")
                            continue
                    elif file_extension == '.pdf':
                        try:
                            pdf_file_obj = open(file_path, 'rb')
                            pdf_reader = PyPDF2.PdfReader(pdf_file_obj)
                            for page_num in range(len(pdf_reader.pages)):
                                page_obj = pdf_reader.pages[page_num]
                                content += page_obj.extract_text() or "" # Handle potential None from extract_text
                            file_type = "pdf"
                            pdf_file_obj.close()
                            print(f"  ✅ Read PDF: {filename}")
                        except Exception as e:
                            print(f"  ❌ Error reading PDF file {filename}: {e}")
                            continue
                    else:
                        print(f"   skipping unsupported file for individual read: {filename}")
                        continue

                    if content:
                        files_data.append({
                            'content': content,
                            'filename': filename,
                            'file_type': file_type
                        })
                        print(f"    Prepared data for {filename} ({file_type}).")


        except Exception as e:
            print(f"❌ An error occurred while reading individual files: {e}")

        print(f"\n🎉 Finished reading {len(files_data)} individual files.")
        return files_data


    def print_directory_structure(self):
        """
        Prints the structure of the data_sources directory.
        """
        print(f"\n=== DATA SOURCES DIRECTORY STRUCTURE: {self.data_sources_path} ===")
        structure = self.get_directory_structure()

        if not structure['root']:
            print("No files found in the data sources directory.")
            return

        print(f"📁 {self.data_sources_path}/")
        for file in structure['root']:
            file_path = os.path.join(self.data_sources_path, file)
            try:
                file_size = os.path.getsize(file_path)
                print(f"  📄 {file} ({file_size:,} bytes)")
            except:
                print(f"  📄 {file}")
        print()


    # Test function (for direct execution of this file)
    def main():
        """Test the DataSourceReader with your directory structure"""
        reader = DataSourceReader()

        # Print directory structure
        reader.print_directory_structure()

        # Test combined text reading
        print("\n--- Testing Combined Text Reading ---")
        all_combined_text = reader.read_all_files_into_single_string()
        print(f"Total combined text length: {len(all_combined_text)} characters")
        # print(f"Preview (first 500 chars):\n{all_combined_text[:500]}...")

        # Test individual files reading
        print("\n--- Testing Individual Files Reading ---")
        individual_files_data = reader.read_all_files()
        print(f"Total individual files read: {len(individual_files_data)}")
        for item in individual_files_data:
            print(f"- Filename: {item['filename']}, Type: {item['file_type']}, Content Length: {len(item['content'])}")


if __name__ == "__main__":
    main()