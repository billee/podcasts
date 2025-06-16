"""
Scoring Utilities for ChromaDB Distance-to-Similarity Conversion
Centralizes the scoring logic used across different ChromaDB operations
"""
import re
import logging

def distance_to_score(distance: float) -> float:
    """
    Convert ChromaDB distance to similarity score.

    Args:
        distance (float): Distance value from ChromaDB query results

    Returns:
        float: Similarity score between 0 and 1 (higher = more similar)

    Note:
        - For negative distances: score = 1 / (1 + abs(distance))
        - For positive distances: score = 1 / (1 + distance)
        - Higher scores indicate higher similarity
    """
    if distance < 0:
        # For negative distances, use absolute value and invert
        return 1 / (1 + abs(distance))
    else:
        # For positive distances, use standard conversion
        return 1 / (1 + distance)

def filter_results_by_score(results: dict, score_threshold: float = 0.15) -> list:
    """
    Filter ChromaDB query results based on similarity score threshold.

    Args:
        results (dict): ChromaDB query results with 'documents', 'distances', 'metadatas'
        score_threshold (float): Minimum score threshold (default: 0.15)

    Returns:
        list: Filtered results sorted by score (highest first)

    Each result contains:
        - content: document content
        - score: similarity score
        - distance: original distance
        - metadata: document metadata
    """
    filtered_results = []

    if results and results.get('documents') and results['documents'][0]:
        for i in range(len(results['documents'][0])):
            content = results['documents'][0][i]
            distance = results['distances'][0][i]
            metadata = results['metadatas'][0][i]

            score = distance_to_score(distance)

            print(f"##############: Distance: {distance:.6f}, Score: {score:.6f}")
            print(f"Content: {content[:100]}...")
            print()

            # Filter condition: score must be greater than threshold
            if score > score_threshold:
                logging.info(f"✅ Keeping result: Score {score:.6f} > Threshold {score_threshold}")
                filtered_results.append({
                    'content': clean_text(content),
                    'score': score,
                    'distance': distance,
                    'metadata': metadata
                })
            else:
                logging.info(f"❌ Skipping result: Score {score:.6f} < Threshold {score_threshold}")
                print(f"Content: {content[:100]}...")
                print()


        # Sort by score in descending order (highest similarity first)
        filtered_results.sort(key=lambda x: x['score'], reverse=True)

    return filtered_results


def clean_text(text):
    text = re.sub(r'\n\s*\n', '\n', text)
    text = text.strip()
    return text


def get_all_results_with_scores(results: dict) -> list:
    """
    Convert all ChromaDB results to include scores, regardless of threshold.
    Useful for debugging and analysis.

    Args:
        results (dict): ChromaDB query results

    Returns:
        list: All results with scores, sorted by score (highest first)
    """
    all_results = []

    if results and results.get('documents') and results['documents'][0]:
        for i in range(len(results['documents'][0])):
            content = results['documents'][0][i]
            distance = results['distances'][0][i]
            metadata = results['metadatas'][0][i] if results.get('metadatas') else {}

            score = distance_to_score(distance)

            all_results.append({
                'content': content,
                'score': score,
                'distance': distance,
                'metadata': metadata
            })

    # Sort by score in descending order
    all_results.sort(key=lambda x: x['score'], reverse=True)

    return all_results

def print_score_analysis(results: dict, score_threshold: float = 0.15, max_display: int = 5):
    """
    Print detailed score analysis for debugging purposes.

    Args:
        results (dict): ChromaDB query results
        score_threshold (float): Score threshold for filtering
        max_display (int): Maximum number of results to display
    """
    if not results or not results.get('documents') or not results['documents'][0]:
        print("No results to analyze.")
        return

    all_results = get_all_results_with_scores(results)
    filtered_results = filter_results_by_score(results, score_threshold)

    print(f"Score Analysis:")
    print(f"  Total results: {len(all_results)}")
    print(f"  Results above threshold ({score_threshold}): {len(filtered_results)}")
    print(f"  Score threshold: {score_threshold}")
    print()

    print(f"Top {min(max_display, len(all_results))} results (all scores):")
    print("=" * 80)

    for i, result in enumerate(all_results[:max_display]):
        status = "✅ PASS" if result['score'] > score_threshold else "❌ FILTERED"
        print(f"Result {i+1}: {status}")
        print(f"  Score: {result['score']:.6f}")
        print(f"  Distance: {result['distance']:.6f}")
        print(f"  Content: {result['content'][:150]}...")
        if result['metadata']:
            print(f"  Source: {result['metadata'].get('source', 'Unknown')}")
        print("-" * 40)