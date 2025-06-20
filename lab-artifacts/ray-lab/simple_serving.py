# simple_serving.py - Ray Serve application for MNIST classification
import os
import ray
from ray import serve
import torch
import torch.nn as nn
import torch.nn.functional as F
import numpy as np
from starlette.requests import Request
from starlette.responses import JSONResponse
import signal
import threading
import time
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Global flag for graceful shutdown
shutdown_event = threading.Event()

def signal_handler(signum, frame):
    """Handle shutdown signals gracefully."""
    logger.info(f"Received signal {signum}, initiating graceful shutdown...")
    shutdown_event.set()

def setup_signal_handlers():
    """Set up signal handlers for graceful shutdown only in main thread."""
    if threading.current_thread() is threading.main_thread():
        try:
            signal.signal(signal.SIGTERM, signal_handler)
            signal.signal(signal.SIGINT, signal_handler)
            logger.info("Signal handlers set up successfully")
        except ValueError as e:
            logger.warning(f"Could not set signal handlers: {e}")
    else:
        logger.info("Not in main thread, skipping signal handler setup")

# Same model definition as training
class SimpleCNN(nn.Module):
    def __init__(self):
        super(SimpleCNN, self).__init__()
        self.conv1 = nn.Conv2d(1, 32, 3, 1)
        self.conv2 = nn.Conv2d(32, 64, 3, 1)
        self.dropout1 = nn.Dropout(0.25)
        self.dropout2 = nn.Dropout(0.5)
        self.fc1 = nn.Linear(9216, 128)
        self.fc2 = nn.Linear(128, 10)

    def forward(self, x):
        x = self.conv1(x)
        x = F.relu(x)
        x = self.conv2(x)
        x = F.relu(x)
        x = F.max_pool2d(x, 2)
        x = self.dropout1(x)
        x = torch.flatten(x, 1)
        x = self.fc1(x)
        x = F.relu(x)
        x = self.dropout2(x)
        x = self.fc2(x)
        return F.log_softmax(x, dim=1)

@serve.deployment(num_replicas=2, ray_actor_options={"num_cpus": 1})
class MNISTClassifier:
    def __init__(self):
        self.model = SimpleCNN()
        self.device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        self.model.to(self.device)
        self.model.eval()
        logger.info(f"Model initialized on device: {self.device}")

    async def __call__(self, request: Request) -> JSONResponse:
        try:
            # Parse JSON input
            json_input = await request.json()
            
            if "data" in json_input:
                # Handle raw array data (28x28 flattened or shaped)
                data = np.array(json_input["data"])
                if data.shape == (784,):
                    # Reshape flattened data
                    data = data.reshape(1, 1, 28, 28)
                elif data.shape == (28, 28):
                    # Add batch and channel dimensions
                    data = data.reshape(1, 1, 28, 28)
                elif data.shape == (1, 28, 28):
                    # Add channel dimension
                    data = data.reshape(1, 1, 28, 28)
                elif data.shape != (1, 1, 28, 28):
                    return JSONResponse({"error": f"Invalid data shape: {data.shape}. Expected (784,), (28,28), (1,28,28), or (1,1,28,28)"}, status_code=400)
                
                # Convert to tensor
                input_tensor = torch.FloatTensor(data).to(self.device)
            else:
                return JSONResponse({"error": "Missing 'data' field in JSON"}, status_code=400)
            
            # Make prediction
            with torch.no_grad():
                output = self.model(input_tensor)
                probabilities = F.softmax(output, dim=1)
                predicted_class = torch.argmax(probabilities, dim=1).item()
                confidence = probabilities[0][predicted_class].item()
            
            return JSONResponse({
                "prediction": predicted_class,
                "confidence": float(confidence),
                "probabilities": probabilities[0].tolist()
            })
            
        except Exception as e:
            logger.error(f"Prediction error: {str(e)}")
            return JSONResponse({"error": str(e)}, status_code=500)

def main():
    # Setup signal handlers
    setup_signal_handlers()
    
    # Connect to existing Ray cluster using environment variables
    cluster_name = os.getenv('RAY_CLUSTER_NAME', 'raycluster-ml')
    ray_address = f"ray://{cluster_name}-head-svc:10001"
    
    logger.info(f"Connecting to Ray cluster at: {ray_address}")
    ray.init(address=ray_address)
    logger.info(f"Connected to Ray cluster: {ray.cluster_resources()}")
    
    # Start Ray Serve with HTTP configuration
    logger.info("Starting Ray Serve...")
    serve.start(http_options={"host": "0.0.0.0", "port": 8000})
    
    # Deploy the model
    logger.info("Deploying MNIST classifier...")
    mnist_app = MNISTClassifier.bind()
    
    # Deploy with a specific name and route
    handle = serve.run(mnist_app, name="mnist_classifier", route_prefix="/mnist")
    
    logger.info("MNIST classifier deployed successfully!")
    logger.info("Service is available at port 8000/mnist")
    logger.info("Health check: GET /-/healthz")
    logger.info("Prediction: POST / with JSON body")
    
    # Keep the service running until shutdown signal
    try:
        while not shutdown_event.is_set():
            time.sleep(1)
    except KeyboardInterrupt:
        logger.info("Received keyboard interrupt")
        shutdown_event.set()
    
    logger.info("Shutting down Ray Serve...")
    try:
        serve.shutdown()
    except Exception as e:
        logger.warning(f"Error during serve shutdown: {e}")
    
    try:
        ray.shutdown()
    except Exception as e:
        logger.warning(f"Error during ray shutdown: {e}")
    
    logger.info("Shutdown complete")

if __name__ == "__main__":
    main()
