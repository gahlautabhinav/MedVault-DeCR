# 🏥 MedVault-DeCR

### **Decentralized, Encrypted, Patient-Owned Health Records**

> A next-generation Electronic Health Record (EHR) system powered by **Polygon blockchain** and **Storacha (IPFS)**, giving patients full ownership, privacy, and control over their medical data.

---

## 🚀 Overview

**MedVault-DeCR** combines:

* 🔗 **Polygon Blockchain** → Low-cost, high-speed, scalable transactions
* 📱 **Flutter Frontend** → Cross-platform healthcare access
* 🔐 **End-to-End Encryption** → Privacy-first architecture
* ☁️ **Storacha (IPFS)** → Decentralized, content-addressed storage

This ensures a **secure, scalable, and patient-centric healthcare ecosystem**.

---

## 🧠 Why This Matters

Traditional EHR systems suffer from:

* ❌ Centralized control
* ❌ Data silos
* ❌ Security vulnerabilities

**MedVault-DeCR solves this with:**

* ✅ Patient-owned data
* ✅ Cryptographic security
* ✅ Transparent access logs
* ✅ Interoperable sharing

---

## ✨ Core Features

* 👤 **Patient Sovereignty** → Full control over records
* 🔐 **AES-256 Encryption** → Secure file protection
* 🔗 **Smart Contract Access Control** → On-chain permissions
* 🧾 **Immutable Audit Logs** → Tamper-proof tracking
* 📱 **Flutter App** → Mobile-first UX
* ☁️ **Storacha (IPFS)** → Decentralized storage layer
* 💰 **Data Monetization (Optional)** → Consent-based sharing

---

## 🏗️ Architecture

```text
             ┌──────────────────────────────┐
             │     Flutter Frontend App     │
             │  (Android | iOS | Web-ready) │
             └──────────────┬───────────────┘
                            │
                            ▼
             ┌──────────────────────────────┐
             │      Backend (Node.js)       │
             │ Auth + Encryption + APIs     │
             └──────────────┬───────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        ▼                                       ▼
┌──────────────────────┐            ┌────────────────────────┐
│ Polygon Smart Contracts│          │ Storacha (IPFS Storage)│
│ - Access Control       │          │ - Encrypted Files       │
│ - Audit Logs           │          │ - Content-addressed     │
└──────────────────────┘            └────────────────────────┘
```

---

## 📱 Frontend (Flutter)

Built with **Flutter** for a seamless multi-platform experience:

* 📲 Android & iOS support
* ⚡ Fast, responsive UI
* 🔐 Secure API communication
* 🔗 Wallet integration (MetaMask / WalletConnect)

### Responsibilities:

* Upload & encrypt records
* Manage permissions
* Access medical history
* Interact with blockchain

---

## 🧰 Tech Stack

| Layer          | Technology                       |
| -------------- | -------------------------------- |
| **Frontend**   | Flutter (Dart)                   |
| **Blockchain** | Polygon (EVM), Solidity, Hardhat |
| **Backend**    | Node.js, Express                 |
| **Storage**    | Storacha (IPFS)                  |
| **Security**   | AES-256-GCM, SHA-256, JWT        |
| **Wallet**     | MetaMask / WalletConnect         |

---

## ⚙️ How It Works

### 🧑 Patient Flow

1. Connect wallet via Flutter app
2. Upload record → encrypted locally
3. Stored on Storacha → hash stored on Polygon
4. Grant/revoke access via smart contract

---

### 🧑‍⚕️ Doctor Flow

1. Request access using patient ID / QR
2. Smart contract validates permission
3. Retrieve encrypted data from Storacha
4. Decrypt and view securely

---

### 📊 Audit Flow

* Every access is logged on **Polygon blockchain**
* Fully transparent and immutable

---

## 📂 Project Structure

```bash
MedVault-DeCR/
├── contracts/          # Solidity smart contracts
├── backend/            # Node.js / Express API
├── frontend/           # Flutter app
│   ├── lib/
│   ├── assets/
│   └── pubspec.yaml
├── scripts/            # Deployment scripts
├── config/
└── README.md
```

---

## 🏁 Installation & Setup

### 1️⃣ Clone Repository

```bash
git clone https://github.com/gahlautabhinav/MedVault-DeCR.git
cd MedVault-DeCR
```

---

### 2️⃣ Backend Setup

```bash
cd backend
npm install
npm run dev
```

---

### 3️⃣ Flutter Setup

```bash
cd frontend
flutter pub get
flutter run
```

---

### 4️⃣ Environment Variables

```env
PRIVATE_KEY=
RPC_URL= (Polygon RPC URL)
JWT_SECRET=
ENCRYPTION_KEY=
STORACHA_API_KEY=
```

---

### 5️⃣ Deploy Contracts (Polygon)

```bash
cd scripts
npx hardhat deploy --network polygon
```

---

## 🔐 Security Architecture

* 🔑 Client-side encryption before upload
* 🔒 No plaintext data stored
* 🧾 Hash verification via blockchain
* 🔍 Role-based smart contract enforcement

---

## 📈 Future Roadmap

* [ ] 🔐 Zero-Knowledge Proofs (ZKP)
* [ ] 🧠 AI-powered diagnostics (privacy-preserving)
* [ ] 🪪 Decentralized Identity (DID)
* [ ] 📱 Advanced Flutter dashboards
* [ ] 🌐 Multi-chain support

---

## 🤝 Contributing

```bash
git checkout -b feat/your-feature
```

* Follow clean architecture
* Write testable code
* Open detailed PR

---

## 📜 License

MIT License
[https://opensource.org/licenses/MIT](https://opensource.org/licenses/MIT)

---

## 🌍 Vision

> "Healthcare data should be owned by patients, secured by cryptography, and shared only with consent."
