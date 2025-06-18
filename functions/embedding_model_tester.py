# model_comparison.py
import chromadb
from chromadb.utils import embedding_functions
import time
from typing import List, Dict
from scoring_utils import print_score_analysis, filter_results_by_score

class EmbeddingModelTester:
    def __init__(self, db_path: str = "./chroma_db"):
        self.db_path = db_path
        self.test_queries = [

            "medical insurance for caregivers",
            # "mga dokumento para sa trabaho",
            # "pag-uwi sa Pilipinas procedures",
            # "problema sa employer Hong Kong"
        ]

        self.models_to_test = [
            # "sentence-transformers/paraphrase-multilingual-mpnet-base-v2",  # Current
            # "sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2",
            # "sentence-transformers/distiluse-base-multilingual-cased-v2",
            # "sentence-transformers/all-MiniLM-L12-v2",
            # "sentence-transformers/all-mpnet-base-v2",
            # "intfloat/multilingual-e5-base",
            "intfloat/multilingual-e5-small"
        ]

    def test_model_performance(self, model_name: str) -> Dict:
        """Test a single model's performance"""
        print(f"\n{'='*60}")
        print(f"Testing: {model_name}")
        print(f"{'='*60}")

        try:
            # Initialize client with the model
            client = chromadb.PersistentClient(path=self.db_path)
            embedding_function = embedding_functions.SentenceTransformerEmbeddingFunction(
                model_name=model_name
            )

            # Create temporary collection for testing
            test_collection_name = f"test_{model_name.replace('/', '_').replace('-', '_')}"

            # Try to get existing collection or skip if it doesn't exist
            try:
                collection = client.get_collection(
                    name="ofw_knowledge",  # Use your existing collection
                    embedding_function=embedding_function
                )
            except:
                print(f"❌ Collection not found for {model_name}")
                return {"model": model_name, "error": "Collection not found"}

            # Test queries
            results = {}
            total_time = 0

            for query in self.test_queries:
                start_time = time.time()

                query_results = collection.query(
                    query_texts=[query],
                    n_results=5,
                    include=['documents', 'distances', 'metadatas']
                )

                query_time = time.time() - start_time
                total_time += query_time

                # Filter results by score
                filtered_results = filter_results_by_score(query_results, score_threshold=0.15)

                results[query] = {
                    "query_time": query_time,
                    "total_results": len(query_results['documents'][0]) if query_results['documents'] else 0,
                    "filtered_results": len(filtered_results),
                    "top_score": filtered_results[0]['score'] if filtered_results else 0.0,
                    "avg_score": sum(r['score'] for r in filtered_results) / len(filtered_results) if filtered_results else 0.0
                }

                print(f"Query: '{query[:40]}...'")
                print(f"  Results: {len(filtered_results)}/5, Top score: {results[query]['top_score']:.4f}, Avg score: {results[query]['avg_score']:.4f}")

            # Calculate overall metrics
            avg_query_time = total_time / len(self.test_queries)
            avg_results_count = sum(r['filtered_results'] for r in results.values()) / len(results)
            avg_top_score = sum(r['top_score'] for r in results.values()) / len(results)
            overall_avg_score = sum(r['avg_score'] for r in results.values()) / len(results)

            performance_summary = {
                "model": model_name,
                "avg_query_time": avg_query_time,
                "avg_results_count": avg_results_count,
                "avg_top_score": avg_top_score,
                "overall_avg_score": overall_avg_score,
                "detailed_results": results
            }

            print(f"\n📊 Summary for {model_name}:")
            print(f"  Avg Query Time: {avg_query_time:.3f}s")
            print(f"  Avg Results Count: {avg_results_count:.1f}")
            print(f"  Avg Top Score: {avg_top_score:.4f}")
            print(f"  Overall Avg Score: {overall_avg_score:.4f}")

            return performance_summary

        except Exception as e:
            print(f"❌ Error testing {model_name}: {e}")
            return {"model": model_name, "error": str(e)}

    def run_comparison(self):
        """Run comparison across all models"""
        print("🚀 Starting embedding model comparison...")
        print("This will test multiple models against your existing ChromaDB collection.")

        all_results = []

        for model_name in self.models_to_test:
            result = self.test_model_performance(model_name)
            all_results.append(result)
            time.sleep(1)  # Brief pause between tests

        # Generate comparison report
        self.generate_comparison_report(all_results)

        return all_results

    def generate_comparison_report(self, results: List[Dict]):
        """Generate a comprehensive comparison report"""
        print(f"\n{'='*80}")
        print("🏆 EMBEDDING MODEL COMPARISON REPORT")
        print(f"{'='*80}")

        valid_results = [r for r in results if 'error' not in r]

        if not valid_results:
            print("❌ No valid results to compare")
            return

        # Sort by overall average score (descending)
        valid_results.sort(key=lambda x: x['overall_avg_score'], reverse=True)

        print("\n📊 RANKING BY OVERALL AVERAGE SCORE:")
        print("-" * 80)
        for i, result in enumerate(valid_results, 1):
            model_name = result['model'].split('/')[-1]  # Get just the model name
            print(f"{i}. {model_name}")
            print(f"   Overall Avg Score: {result['overall_avg_score']:.4f}")
            print(f"   Avg Top Score: {result['avg_top_score']:.4f}")
            print(f"   Avg Results Count: {result['avg_results_count']:.1f}")
            print(f"   Avg Query Time: {result['avg_query_time']:.3f}s")
            print()

        # Performance insights
        best_model = valid_results[0]
        fastest_model = min(valid_results, key=lambda x: x['avg_query_time'])
        most_results = max(valid_results, key=lambda x: x['avg_results_count'])

        print("🎯 KEY INSIGHTS:")
        print(f"  🥇 Best Overall: {best_model['model'].split('/')[-1]} (Score: {best_model['overall_avg_score']:.4f})")
        print(f"  ⚡ Fastest: {fastest_model['model'].split('/')[-1]} ({fastest_model['avg_query_time']:.3f}s)")
        print(f"  📈 Most Results: {most_results['model'].split('/')[-1]} ({most_results['avg_results_count']:.1f} avg)")

        # Recommendation
        print(f"\n💡 RECOMMENDATION:")
        if best_model['model'] == "sentence-transformers/paraphrase-multilingual-mpnet-base-v2":
            print("   Your current model is performing the best! Consider keeping it.")
        else:
            print(f"   Consider switching to: {best_model['model']}")
            print(f"   Improvement: {best_model['overall_avg_score']:.4f} vs current model score")

def main():
    """Main function to run the comparison"""
    tester = EmbeddingModelTester()
    results = tester.run_comparison()

    # Save results to file
    import json
    with open('embedding_model_comparison.json', 'w') as f:
        json.dump(results, f, indent=2)

    print(f"\n💾 Results saved to 'embedding_model_comparison.json'")

if __name__ == "__main__":
    main()