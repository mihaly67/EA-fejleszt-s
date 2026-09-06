import torch
import torch.nn as nn

class MetaAdvisorLSTM(nn.Module):
    def __init__(self, input_dim=30, hidden_dim=64, num_layers=2, output_dim=1):
        super(MetaAdvisorLSTM, self).__init__()
        self.hidden_dim = hidden_dim
        self.num_layers = num_layers

        # LSTM layer to process the sequence of dollar bars
        self.lstm = nn.LSTM(input_dim, hidden_dim, num_layers, batch_first=True, dropout=0.2)

        # Fully connected layers for meta-decision
        self.fc1 = nn.Linear(hidden_dim, 32)
        self.relu = nn.ReLU()
        self.dropout = nn.Dropout(0.2)

        # Binary output: 1 (LGBM was right, follow signal), 0 (LGBM was wrong, ignore signal)
        self.fc2 = nn.Linear(32, output_dim)
        self.sigmoid = nn.Sigmoid()

    def forward(self, x):
        # x shape: (batch_size, sequence_length, input_dim)

        # Initialize hidden state and cell state
        h0 = torch.zeros(self.num_layers, x.size(0), self.hidden_dim).to(x.device)
        c0 = torch.zeros(self.num_layers, x.size(0), self.hidden_dim).to(x.device)

        # Forward propagate LSTM
        out, _ = self.lstm(x, (h0, c0))

        # Decode the hidden state of the last time step
        out = out[:, -1, :]

        out = self.fc1(out)
        out = self.relu(out)
        out = self.dropout(out)
        out = self.fc2(out)

        # Sigmoid for probability (0.0 to 1.0)
        out = self.sigmoid(out)
        return out
