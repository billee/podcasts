import PyPDF2

def extract_pdf_text(filepath):
    """Extract text from government PDFs"""
    with open(filepath, 'rb') as file:
        reader = PyPDF2.PdfReader(file)
        return '\n'.join(
            [page.extract_text() for page in reader.pages]
        )

# Example usage:
# content = extract_pdf_text('data_sources/government_guides/owwa_benefits.pdf')
# Add to AppConstants.government_guides programmatically