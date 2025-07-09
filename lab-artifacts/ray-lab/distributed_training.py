# distributed_training.py - Distributed PyTorch training with Ray Train
import os
import tempfile
import torch
import torch.nn as nn
import torch.nn.functional as F
from torch.utils.data import DataLoader
from torchvision import datasets, transforms
import ray
from ray import train
from ray.train import Checkpoint, ScalingConfig
from ray.train.torch import TorchTrainer

# Define a simple CNN model
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

def train_func(config):
    # Model setup
    model = SimpleCNN()
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    model.to(device)
    
    # Data setup
    transform = transforms.Compose([
        transforms.ToTensor(),
        transforms.Normalize((0.1307,), (0.3081,))
    ])
    
    train_dataset = datasets.MNIST(
        root="/tmp/data",
        train=True,
        download=True,
        transform=transform
    )
    
    # Create data loader - Ray Train handles data distribution automatically
    train_loader = DataLoader(
        train_dataset,
        batch_size=config["batch_size"],
        shuffle=True
    )
    
    # Wrap model and data loader for distributed training
    model = train.torch.prepare_model(model)
    train_loader = train.torch.prepare_data_loader(train_loader)
    
    optimizer = torch.optim.Adam(model.parameters(), lr=config["lr"])
    loss_fn = nn.CrossEntropyLoss()
    
    # Training loop
    for epoch in range(config["epochs"]):
        model.train()
        running_loss = 0.0
        correct = 0
        total = 0
        
        for batch_idx, (data, target) in enumerate(train_loader):
            data, target = data.to(device), target.to(device)
            optimizer.zero_grad()
            output = model(data)
            loss = loss_fn(output, target)
            loss.backward()
            optimizer.step()
            
            running_loss += loss.item()
            _, predicted = torch.max(output.data, 1)
            total += target.size(0)
            correct += (predicted == target).sum().item()
            
            if batch_idx % 100 == 0:
                print(f'Epoch: {epoch}, Batch: {batch_idx}, '
                      f'Loss: {loss.item():.4f}, '
                      f'Accuracy: {100 * correct / total:.2f}%')
        
        # Report metrics to Ray Train
        epoch_loss = running_loss / len(train_loader)
        epoch_acc = 100 * correct / total
        
        # Report metrics without checkpointing to avoid storage issues
        train.report({"loss": epoch_loss, "accuracy": epoch_acc})

def main():
    # Connect to Ray cluster using environment variables
    cluster_name = os.getenv('RAY_CLUSTER_NAME', 'raycluster-ml')
    ray_address = f"ray://{cluster_name}-head-svc:10001"
    ray.init(address=ray_address)
    
    # Configure distributed training for CPU deployment
    scaling_config = ScalingConfig(
        num_workers=2,  # Number of distributed workers
        use_gpu=False   # CPU deployment
    )
    
    # For GPU deployment, use this instead:
    # scaling_config = ScalingConfig(
    #     num_workers=2,
    #     use_gpu=True,
    #     resources_per_worker={"CPU": 2, "GPU": 1}
    # )
    
    # Training configuration
    train_config = {
        "lr": 0.001,
        "batch_size": 64,
        "epochs": 3  # Reduced for testing
    }
    
    # Create and run the trainer
    trainer = TorchTrainer(
        train_loop_per_worker=train_func,
        train_loop_config=train_config,
        scaling_config=scaling_config
    )
    
    result = trainer.fit()
    print(f"Training completed! Final result: {result}")

if __name__ == "__main__":
    main()
