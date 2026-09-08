import torch
import torch.nn as nn

class MetaAdvisorLSTM(nn.Module):
    def __init__(self, input_dim=30, hidden_dim=64, num_layers=2, output_dim=3):
        super(MetaAdvisorLSTM, self).__init__()
        self.hidden_dim = hidden_dim
        self.num_layers = num_layers

        # LSTM layer to process the sequence of dollar bars
        self.lstm = nn.LSTM(input_dim, hidden_dim, num_layers, batch_first=True, dropout=0.2 if num_layers > 1 else 0.0)

        # Fully connected layers for independent prediction
        self.fc1 = nn.Linear(hidden_dim, 32)
        self.relu = nn.ReLU()
        self.dropout = nn.Dropout(0.2)

        # 3 outputs for Multi-class classification: Short (0), Noise (1), Long (2)
        self.fc2 = nn.Linear(32, output_dim)

        # CrossEntropyLoss in PyTorch expects raw logits, so we remove the Sigmoid.
        # We can apply Softmax during inference.

    def forward(self, x):
        h0 = torch.zeros(self.num_layers, x.size(0), self.hidden_dim).to(x.device)
        c0 = torch.zeros(self.num_layers, x.size(0), self.hidden_dim).to(x.device)

        out, _ = self.lstm(x, (h0, c0))
        out = out[:, -1, :]

        out = self.fc1(out)
        out = self.relu(out)
        out = self.dropout(out)
        out = self.fc2(out)

        return out
