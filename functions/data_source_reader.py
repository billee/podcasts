import os
import json
import PyPDF2
from typing import Dict, Any, List

class DataSourceReader:
    def __init__(self, data_sources_path: str = "./data_sources"):
        self.data_sources_path = data_sources_path

    def read_all_files_into_single_string(self) -> str:
        """
        Read all supported files from the data_sources directory, including subdirectories.
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

        print(f"🚀 Reading files from: {self.data_sources_path} (including subdirectories)")

        try:
            for root, _, files in os.walk(self.data_sources_path):
                for filename in files:
                    file_path = os.path.join(root, filename)
                    file_extension = os.path.splitext(filename)[1].lower()
                    content = ""

                    if file_extension == '.txt':
                        try:
                            with open(file_path, 'r', encoding='utf-8') as f:
                                content = f.read()
                            print(f"  ✅ Read TXT: {file_path}")
                        except Exception as e:
                            print(f"  ❌ Error reading TXT file {file_path}: {e}")
                            continue
                    elif file_extension == '.json':
                        try:
                            with open(file_path, 'r', encoding='utf-8') as f:
                                json_data = json.load(f)
                                content = json.dumps(json_data, indent=2) # Convert JSON object to string
                            print(f"  ✅ Read JSON: {file_path}")
                        except Exception as e:
                            print(f"  ❌ Error reading JSON file {file_path}: {e}")
                            continue
                    elif file_extension == '.pdf':
                        try:
                            pdf_file_obj = open(file_path, 'rb')
                            pdf_reader = PyPDF2.PdfReader(pdf_file_obj)
                            for page_num in range(len(pdf_reader.pages)):
                                page_obj = pdf_reader.pages[page_num]
                                content += page_obj.extract_text() or "" # Handle potential None from extract_text
                            pdf_file_obj.close()
                            print(f"  ✅ Read PDF: {file_path}")
                        except Exception as e:
                            print(f"  ❌ Error reading PDF file {file_path}: {e}")
                            continue
                    elif file_extension == '.md':
                        try:
                            with open(file_path, 'r', encoding='utf-8') as f:
                                content = f.read()
                            print(f"  ✅ Read Markdown: {file_path}")
                        except Exception as e:
                            print(f"  ❌ Error reading Markdown file {file_path}: {e}")
                            continue
                    elif file_extension == '.docx':
                        print(f"  ⚠️ Skipping DOCX file: {file_path}. Install 'python-docx' library for full functionality.")
                        continue # Skip DOCX for now, similar to original chroma_setup.py
                    else:
                        print(f"   skipping unsupported file: {file_path}")
                        continue

                    if content:
                        all_string += content + "%%"
                        print(f"    Added content from {file_path} to all_string.")

        except Exception as e:
            print(f"❌ An error occurred while reading files: {e}")

        print(f"\n🎉 Finished reading all files. Total content length: {len(all_string)} characters.")
        return all_string

    def read_all_files(self) -> List[Dict[str, Any]]:
        """
        Read all supported files from the data_sources directory, including subdirectories.
        Returns a list of dictionaries, where each dictionary contains
        'content', 'filename', 'file_type', and 'source_path'.
        Supported formats: .txt, .json, .pdf, .md
        This method is for populating vector databases to retain metadata.
        """
        files_data = []

        if not os.path.exists(self.data_sources_path):
            print(f"Data sources path '{self.data_sources_path}' does not exist.")
            return files_data

        if not os.path.isdir(self.data_sources_path):
            print(f"Path '{self.data_sources_path}' is not a directory.")
            return files_data

        print(f"🚀 Reading individual files from: {self.data_sources_path} (including subdirectories)")

        try:
            for root, _, files in os.walk(self.data_sources_path):
                for filename in files:
                    file_path = os.path.join(root, filename)
                    file_extension = os.path.splitext(filename)[1].lower()
                    content = ""
                    file_type = ""

                    if file_extension == '.txt':
                        try:
                            with open(file_path, 'r', encoding='utf-8') as f:
                                content = f.read()
                            file_type = "txt"
                            print(f"  ✅ Read TXT: {file_path}")
                        except Exception as e:
                            print(f"  ❌ Error reading TXT file {file_path}: {e}")
                            continue
                    elif file_extension == '.json':
                        try:
                            with open(file_path, 'r', encoding='utf-8') as f:
                                json_data = json.load(f)
                                content = json.dumps(json_data, indent=2) # Convert JSON object to string
                            file_type = "json"
                            print(f"  ✅ Read JSON: {file_path}")
                        except Exception as e:
                            print(f"  ❌ Error reading JSON file {file_path}: {e}")
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
                            print(f"  ✅ Read PDF: {file_path}")
                        except Exception as e:
                            print(f"  ❌ Error reading PDF file {file_path}: {e}")
                            continue
                    elif file_extension == '.md':
                        try:
                            with open(file_path, 'r', encoding='utf-8') as f:
                                content = f.read()
                            file_type = "md"
                            print(f"  ✅ Read Markdown: {file_path}")
                        except Exception as e:
                            print(f"  ❌ Error reading Markdown file {file_path}: {e}")
                            continue
                    elif file_extension == '.docx':
                        print(f"  ⚠️ Skipping DOCX file: {file_path}. Install 'python-docx' library for full functionality.")
                        continue # Skip DOCX for now, similar to original chroma_setup.py
                    else:
                        print(f"   skipping unsupported file for individual read: {file_path}")
                        continue

                    if content:
                        relative_path = os.path.relpath(file_path, self.data_sources_path)
                        files_data.append({
                            'content': content,
                            'filename': filename,
                            'file_type': file_type,
                            'source_path': relative_path # Store the relative path here
                        })
                        print(f"    Prepared data for {file_path} ({file_type}).")


        except Exception as e:
            print(f"❌ An error occurred while reading individual files: {e}")

        print(f"\n🎉 Finished reading {len(files_data)} individual files.")
        return files_data

    def get_directory_structure(self):
        """
        Gets the structure of the data_sources directory including subdirectories.
        Returns a dictionary representing the tree structure.
        """
        structure = {'root': []}
        for root, dirs, files in os.walk(self.data_sources_path):
            level = root.replace(self.data_sources_path, '').count(os.sep)
            indent = ' ' * 4 * (level)
            # Add directories
            for d in dirs:
                structure['root'].append(f"{indent}📁 {os.path.basename(d)}/")
            # Add files
            for f in files:
                file_path = os.path.join(root, f)
                try:
                    file_size = os.path.getsize(file_path)
                    structure['root'].append(f"{indent}  📄 {f} ({file_size:,} bytes)")
                except:
                    structure['root'].append(f"{indent}  📄 {f}")
        return structure


    def print_directory_structure(self):
        """
        Prints the structure of the data_sources directory including subdirectories.
        """
        print(f"\n=== DATA SOURCES DIRECTORY STRUCTURE: {self.data_sources_path} ===")
        # Re-using the logic from get_directory_structure to print directly
        for root, dirs, files in os.walk(self.data_sources_path):
            level = root.replace(self.data_sources_path, '').count(os.sep)
            indent = ' ' * 4 * (level)
            # Print current directory
            print(f"{indent}📁 {os.path.basename(root)}/")
            # Print files in current directory
            for f in files:
                file_path = os.path.join(root, f)
                try:
                    file_size = os.path.getsize(file_path)
                    print(f"{indent}  📄 {f} ({file_size:,} bytes)")
                except:
                    print(f"{indent}  📄 {f}")
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
        print(f"- Filename: {item['filename']}, Type: {item['file_type']}, Content Length: {len(item['content'])}, Source Path: {item['source_path']}")


if __name__ == "__main__":
    main()