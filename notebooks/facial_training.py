"""
Facial PD Detection Model Training — based on UFNet (AAAI 2025)

Trains a ShallowANN on the UFNet smile task dataset for binary PD classification.
Architecture: Linear(n_features → 1) + Dropout + Sigmoid

Usage:
    python notebooks/facial_training.py

Output:
    neuroverse-backend/app/ml/models/facial_model.pt
    neuroverse-backend/app/ml/models/facial_scaler.pkl
"""

import os
import sys
import copy
import random
import pickle

import numpy as np
import pandas as pd
import torch
import torch.nn as nn
from torch.utils.data import Dataset, DataLoader
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import accuracy_score, roc_auc_score, f1_score, confusion_matrix
from imblearn.over_sampling import SMOTE

# ---------- Configuration (from UFNet paper best hyperparameters) ----------
SEED = 462
RANDOM_STATE = 154
BATCH_SIZE = 256
NUM_EPOCHS = 64
LEARNING_RATE = 0.03265227174722892
MOMENTUM = 0.5450637936769563
DROPOUT_PROB = 0.10661756438565197
CORR_THR = 0.95
DROP_CORRELATED = False
USE_SCALING = True
MINORITY_OVERSAMPLE = True

# Paths
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UFNet_DIR = os.path.join(BASE_DIR, "UFNet")
FEATURES_FILE = os.path.join(UFNet_DIR, "data/facial_expression_smile/facial_dataset.csv")
DEV_IDS_FILE = os.path.join(UFNet_DIR, "data/dev_set_participants.txt")
TEST_IDS_FILE = os.path.join(UFNet_DIR, "data/test_set_participants.txt")
OUTPUT_MODEL = os.path.join(BASE_DIR, "neuroverse-backend/app/ml/models/facial_model.pt")
OUTPUT_SCALER = os.path.join(BASE_DIR, "neuroverse-backend/app/ml/models/facial_scaler.pkl")

# Facial expressions to use (from UFNet constants)
FACIAL_EXPRESSIONS = {'smile': True, 'surprise': False, 'disgust': False}

# Set seeds
random.seed(SEED)
np.random.seed(SEED)
torch.manual_seed(SEED)
torch.cuda.manual_seed_all(SEED)
torch.backends.cudnn.deterministic = True
torch.backends.cudnn.benchmark = False

device = 'cuda' if torch.cuda.is_available() else 'cpu'
print(f"Running on {device}")


# ---------- Dataset ----------
class TensorDataset(Dataset):
    def __init__(self, features, labels):
        self.features = torch.Tensor(np.asarray(features))
        self.labels = torch.Tensor(labels)

    def __getitem__(self, index):
        return self.features[index], self.labels[index]

    def __len__(self):
        return len(self.labels)


# ---------- Model (ShallowANN from UFNet) ----------
class ShallowANN(nn.Module):
    def __init__(self, n_features, drop_prob=0.1):
        super().__init__()
        self.fc = nn.Linear(in_features=n_features, out_features=1, bias=True)
        self.drop = nn.Dropout(p=drop_prob)
        self.sig = nn.Sigmoid()

    def forward(self, x):
        y = self.fc(x)
        y = self.drop(y)
        y = self.sig(y)
        return y


# ---------- Data Loading ----------
def load_data():
    print(f"Loading features from: {FEATURES_FILE}")
    df = pd.read_csv(FEATURES_FILE)
    df.fillna(0, inplace=True)

    # Get smile-related feature columns
    feature_columns = []
    for feature in df.columns:
        for expression in FACIAL_EXPRESSIONS:
            if FACIAL_EXPRESSIONS[expression] and expression in feature.lower():
                feature_columns.append(feature)
                break

    df_features = df[feature_columns]
    print(f"Total samples: {len(df)}, Features: {len(feature_columns)}")

    # Optionally drop highly correlated features
    if DROP_CORRELATED:
        corr_matrix = df_features.corr()
        drop_cols = set()
        for i in range(len(corr_matrix.columns) - 1):
            for j in range(i + 1):
                if abs(corr_matrix.iloc[j, i + 1]) >= CORR_THR:
                    drop_cols.add(corr_matrix.columns[i + 1])
        df.drop(drop_cols, axis=1, inplace=True)
        df_features.drop(drop_cols, axis=1, inplace=True, errors='ignore')
        print(f"Dropped {len(drop_cols)} correlated features")

    features = df_features.to_numpy()

    # Labels: yes/Possible/Probable → 1, no/0 → 0
    labels = df['pd'].apply(lambda x: 0 if str(x) in ['no', '0'] else 1).to_numpy()
    IDs = df['ID']

    print(f"PD: {sum(labels)}, Non-PD: {len(labels) - sum(labels)}")
    return features, labels, IDs, feature_columns


def load_split_ids():
    with open(DEV_IDS_FILE) as f:
        dev_ids = set(x.strip() for x in f.readlines())
    with open(TEST_IDS_FILE) as f:
        test_ids = set(x.strip() for x in f.readlines())
    return dev_ids, test_ids


def split_data(features, labels, ids, dev_ids, test_ids):
    train_f, train_l, dev_f, dev_l, test_f, test_l = [], [], [], [], [], []

    for x, l, pid in zip(features, labels, ids):
        if pid in test_ids:
            test_f.append(x)
            test_l.append(l)
        elif pid in dev_ids:
            dev_f.append(x)
            dev_l.append(l)
        else:
            train_f.append(x)
            train_l.append(l)

    print(f"Train: {len(train_l)}, Dev: {len(dev_l)}, Test: {len(test_l)}")
    return (np.array(train_f), np.array(train_l),
            np.array(dev_f), np.array(dev_l),
            np.array(test_f), np.array(test_l))


# ---------- Evaluation ----------
def evaluate(model, dataloader):
    model.eval()
    all_preds, all_labels = [], []
    criterion = nn.BCELoss()
    total_loss = 0
    n_samples = 0

    with torch.no_grad():
        for x, y in dataloader:
            x, y = x.to(device), y.to(device)
            preds = model(x).reshape(-1)
            loss = criterion(preds, y)
            total_loss += loss.item() * len(y)
            n_samples += len(y)
            all_preds.extend(preds.cpu().numpy())
            all_labels.extend(y.cpu().numpy())

    labels = np.array(all_labels)
    preds = np.array(all_preds)
    pred_binary = (preds >= 0.5).astype(int)

    metrics = {
        'loss': total_loss / max(n_samples, 1),
        'accuracy': accuracy_score(labels, pred_binary),
        'auroc': roc_auc_score(labels, preds) if len(set(labels)) > 1 else 0.0,
        'f1': f1_score(labels, pred_binary, zero_division=0),
    }

    tn, fp, fn, tp = confusion_matrix(labels, pred_binary, labels=[0, 1]).ravel()
    metrics['sensitivity'] = tp / max(tp + fn, 1)
    metrics['specificity'] = tn / max(tn + fp, 1)

    return metrics


# ---------- Main Training ----------
def main():
    features, labels, ids, feature_columns = load_data()
    dev_ids, test_ids = load_split_ids()

    X_train, y_train, X_dev, y_dev, X_test, y_test = split_data(
        features, labels, ids, dev_ids, test_ids
    )

    # Feature scaling
    scaler = None
    if USE_SCALING:
        scaler = StandardScaler()
        X_train = scaler.fit_transform(X_train)
        X_dev = scaler.transform(X_dev)
        X_test = scaler.transform(X_test)
        print("Applied StandardScaler")

    # SMOTE oversampling
    if MINORITY_OVERSAMPLE:
        smote = SMOTE(random_state=RANDOM_STATE)
        X_train, y_train = smote.fit_resample(X_train, y_train)
        print(f"After SMOTE: Train size = {len(y_train)}")

    # Create dataloaders
    train_loader = DataLoader(TensorDataset(X_train, y_train), batch_size=BATCH_SIZE, shuffle=True)
    dev_loader = DataLoader(TensorDataset(X_dev, y_dev), batch_size=BATCH_SIZE)
    test_loader = DataLoader(TensorDataset(X_test, y_test), batch_size=BATCH_SIZE)

    # Model
    n_features = X_train.shape[1]
    model = ShallowANN(n_features, drop_prob=DROPOUT_PROB).to(device)
    print(f"\nShallowANN: {n_features} → 1 (dropout={DROPOUT_PROB})")

    optimizer = torch.optim.SGD(
        model.parameters(), lr=LEARNING_RATE, momentum=MOMENTUM, weight_decay=0.0001
    )
    criterion = nn.BCELoss()

    best_dev_loss = float('inf')
    best_model = copy.deepcopy(model)

    # Training loop
    print(f"\nTraining for {NUM_EPOCHS} epochs...")
    for epoch in range(NUM_EPOCHS):
        model.train()
        epoch_loss = 0
        for x, y in train_loader:
            x, y = x.to(device), y.to(device)
            optimizer.zero_grad()
            preds = model(x).reshape(-1)
            loss = criterion(preds, y)
            loss.backward()
            optimizer.step()
            epoch_loss += loss.item()

        # Evaluate on dev set
        dev_metrics = evaluate(model, dev_loader)
        if dev_metrics['loss'] < best_dev_loss:
            best_dev_loss = dev_metrics['loss']
            best_model = copy.deepcopy(model)

        if (epoch + 1) % 10 == 0 or epoch == 0:
            print(f"  Epoch {epoch+1:3d}: loss={dev_metrics['loss']:.4f}, "
                  f"acc={dev_metrics['accuracy']:.3f}, auroc={dev_metrics['auroc']:.3f}")

    # Final evaluation on test set
    print("\n" + "=" * 50)
    print("Test set evaluation (best model):")
    test_metrics = evaluate(best_model, test_loader)
    for k, v in test_metrics.items():
        print(f"  {k}: {v:.4f}")

    # Save model
    os.makedirs(os.path.dirname(OUTPUT_MODEL), exist_ok=True)
    torch.save(best_model.cpu().state_dict(), OUTPUT_MODEL)
    print(f"\nModel saved to: {OUTPUT_MODEL}")
    print(f"  Features: {n_features}")

    # Save scaler
    if scaler is not None:
        with open(OUTPUT_SCALER, "wb") as f:
            pickle.dump(scaler, f)
        print(f"Scaler saved to: {OUTPUT_SCALER}")

    # Save feature column names for reference
    info_path = os.path.join(os.path.dirname(OUTPUT_MODEL), "facial_model_info.txt")
    with open(info_path, "w") as f:
        f.write(f"n_features: {n_features}\n")
        f.write(f"feature_columns: {feature_columns}\n")
        f.write(f"test_metrics: {test_metrics}\n")
    print(f"Model info saved to: {info_path}")


if __name__ == "__main__":
    main()
