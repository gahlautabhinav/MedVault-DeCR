# MedVault-DeCR

**MedVault‑DeCR** is a **decentralized Electronic Health Record (EHR) system** built on blockchain (Ethereum‑compatible smart contracts) that gives patients full control over their medical data while enabling secure, auditable sharing with doctors, hospitals, and researchers.  

This project ties together a **smart‑contract backend**, an **encrypted vault** for storing medical records off‑chain, and a **web frontend** for patients and healthcare providers to interact with the system.

---

## 📌 Features

- **Patient‑centric control**: Patients own their medical records and can grant or revoke access to specific providers.  
- **Decentralized storage**: Large files (PDFs, images, etc.) are stored securely off‑chain, while hashes and access metadata live on‑chain.  
- **Role‑based access**: Doctors, hospitals, and admins are assigned roles; permissions are enforced via smart contracts.  
- **Immutable audit trail**: Every read/write and access‑change is logged on the blockchain for transparency and compliance.  
- **End‑to‑end encryption**: Records are encrypted (e.g., AES‑256) so only authorized parties can decrypt them.  
- **Optional data monetization**: Patients can allow anonymized, aggregated data to be used for research under predefined conditions.

---

## 📦 Tech Stack

- **Blockchain layer**: Ethereum‑compatible smart contracts (Solidity) deployed via Ganache or testnet.  
- **Backend**: Node.js / Express (or similar) to handle user authentication, file uploads, and contract interactions.  
- **Frontend**: React (or similar) with MetaMask‑style wallet integration for signing transactions and managing permissions.  
- **Storage**: Encrypted cloud storage or IPFS for storing medical document blobs.  
- **Security**: Hashing (e.g., SHA‑256), JWT‑based auth, and AES‑256‑GCM‑style encryption.

---

## 🧭 How to Use (High‑Level)

1. **Patient flows**  
   - Register a patient account (wallet‑based identity).  
   - Upload medical records (e.g., lab reports, prescriptions) that get encrypted and stored off‑chain.  
   - Grant access to specific doctors/hospitals by updating smart‑contract permissions.  

2. **Doctor / Hospital flows**  
   - Scan a patient’s QR‑style vault key or ID.  
   - Request decryption keys or ciphertexts via the smart contract.  
   - View only the records for which access is allowed.  

3. **Audit & Compliance**  
   - Query the blockchain to see full access history (who accessed which record, when, and for what purpose).

---

## 📂 Project Structure (Example)

After cloning, a typical layout:

```
MedVault-DeCR/
├── contracts/          # Solidity smart contracts
├── backend/            # Node.js / Express server
│   ├── routes/
│   ├── controllers/
│   └── middleware/
├── frontend/           # React web app
│   ├── public/
│   └── src/
├── scripts/            # Deployment scripts (Hardhat / Truffle)
├── config/             # Environment variables & constants
└── README.md           # This file
```

---

## 🏁 Installation & Setup (To‑Do)

Replace with your actual setup steps, but this can be a template:

1. Clone the repo  
   ```bash
   git clone https://github.com/gahlautabhinav/MedVault-DeCR.git
   cd MedVault-DeCR
   ```

2. Install dependencies  
   - Backend:
     ```bash
     cd backend
     npm install
     ```
   - Frontend:
     ```bash
     cd frontend
     npm install
     ```

3. Set environment variables  
   - Copy `.env.example` to `.env` in both `backend` and (if needed) `frontend`.  
   - Fill in:  
     - `PRIVATE_KEY`, `INFURA_KEY`, or RPC URL for blockchain.  
     - Database / storage credentials.  
     - JWT secret and encryption keys.

4. Deploy contracts  
   ```bash
   cd scripts
   # Run your deployment script (Hardhat/Truffle etc.)
   npx hardhat deploy
   ```

5. Start services  
   - Backend: `npm run start` (or `nodemon`)  
   - Frontend: `npm start`  

6. Open the app in the browser (e.g., `http://localhost:3000`).

---

## 🧩 How to Contribute

Contributions are welcome! You can help with:

- Adding new contract features (e.g., data‑sharing consent tiers).  
- Improving UI/UX for patients and doctors.  
- Writing tests (unit and integration) for contracts and backend.  
- Updating documentation and examples.

To contribute:
1. Fork the repo.  
2. Create a feature branch: `git checkout -b feat/your-feature`.  
3. Commit and push your changes.  
4. Open a pull request with a clear description.

---

## 📄 License

This project is open‑source and released under the **[MIT License](https://opensource.org/licenses/MIT)**.  
See the `LICENSE` file for details.

You can paste this as `MedVault-DeCR/README.md` and then edit the **Installation & Setup**, **Project Structure**, and **Contact** sections to match exactly what you have in your repo.
