import os
import ray
import pandas as pd
import numpy as np
from ray.data import Dataset
import time

def main():
    # Connect to Ray cluster using environment variables
    ray_dashboard_url = os.getenv('RAY_DASHBOARD_URL', 'ray://localhost:10001')
    
    try:
        ray.init(address=ray_dashboard_url)
        print(f"Connected to Ray cluster at {ray_dashboard_url}")
        print(f"Ray cluster resources: {ray.cluster_resources()}")
        
        # Create sample dataset
        print("\n=== Creating sample dataset ===")
        data = []
        for i in range(100000):
            data.append({
                'id': i,
                'value': np.random.random(),
                'category': np.random.choice(['A', 'B', 'C', 'D']),
                'timestamp': pd.Timestamp.now().isoformat()
            })
        
        # Convert to Ray Dataset
        ds = ray.data.from_pandas(pd.DataFrame(data))
        print(f"Created dataset with {ds.count()} rows")
        
        # Data processing operations
        print("\n=== Processing data ===")
        
        # Filter data
        start_time = time.time()
        filtered_ds = ds.filter(lambda row: row['value'] > 0.5)
        print(f"Filtered dataset: {filtered_ds.count()} rows (took {time.time() - start_time:.2f}s)")
        
        # Group by category and aggregate
        start_time = time.time()
        grouped_ds = filtered_ds.groupby('category').mean(['value'])
        results = grouped_ds.take_all()
        print(f"Grouped data processing took {time.time() - start_time:.2f}s")
        
        # Display results
        print("\n=== Results ===")
        for result in results:
            print(f"Category {result['category']}: Average value = {result['mean(value)']:.4f}")
        
        # Advanced processing with map_batches
        print("\n=== Advanced batch processing ===")
        
        def process_batch(batch):
            """Process a batch of data with custom logic"""
            batch['processed_value'] = batch['value'] * 2 + np.random.normal(0, 0.1, len(batch))
            batch['value_category'] = pd.cut(batch['value'], bins=3, labels=['Low', 'Medium', 'High'])
            return batch
        
        start_time = time.time()
        processed_ds = ds.map_batches(process_batch, batch_format="pandas")
        sample_results = processed_ds.take(10)
        print(f"Batch processing took {time.time() - start_time:.2f}s")
        
        # Display sample processed results
        print("\nSample processed data:")
        for i, result in enumerate(sample_results[:5]):
            print(f"Row {i}: original={result['value']:.4f}, processed={result['processed_value']:.4f}, category={result['value_category']}")
        
        # Save processed data (optional)
        output_path = os.getenv('RAY_OUTPUT_PATH', '/tmp/ray_processed_data')
        print(f"\n=== Saving results to {output_path} ===")
        processed_ds.write_parquet(output_path)
        print("Data processing completed successfully!")
        
    except Exception as e:
        print(f"Error during data processing: {e}")
        raise
    finally:
        ray.shutdown()
        print("Ray connection closed")

if __name__ == "__main__":
    main()
