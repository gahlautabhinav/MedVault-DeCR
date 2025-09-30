# MedVault-DeCR
### Team: Kodak

A decentralized medical records vault with patient-controlled consent, secure file sharing, and on-chain audit logging.

Built for the 0xGenIgnite Hackathon (NIT Goa) 🚀

Note: We completed the MVP, we were working on deployment, it is still in process.

# ⚙️ Setup Instructions
## 1. Backend (Node.js)
- cd backend
- npm install
- cp .env.example .env   # add your RPC, private key, contract addresses
- node server.js         # starts API server on http://localhost:3001
- node indexer.js        # runs blockchain event indexer

### APIs available:
- POST /api/upload → upload medical file to IPFS (Web3.Storage)
- POST /api/upload-key → upload encrypted key JSON
- POST /api/grant-access → grant doctor access
- POST /api/revoke-access → revoke access
- POST /api/emergency-access → emergency override
- GET /api/audit → fetch local audit logs
- GET /api/onchain-audit → fetch on-chain audit (ConsentManager + AuditLogger)
- GET /api/grants → current active grants

## 2. Frontend (Flutter)
- cd frontend
- flutter pub get
- flutter run -d chrome   # run in Chrome browser

### Features (Patient dashboard MVP):
- Upload files
- Upload encrypted key JSON
- Grant / revoke / emergency access
- View active grants
- View combined audit log (local + on-chain)

## 3. Blockchain (Contracts)
- cd blockchain
- npm install
- npx hardhat compile
- npx hardhat run scripts/deploy.js --network amoy

Deployed addresses will be saved to deployments/

## 🔒 Tech Stack
- Backend: Node.js, Express, ethers.js, IPFS (Web3.Storage
- Frontend: Flutter (Dart, Material UI)
- Blockchain: Solidity (ConsentManager, AuditLogger), Hardhat
- Database: Local JSON (audit_db.json) for MVP

## 🌟 Hackathon Highlights
1. Patients own and control medical data (DID + IPFS storage).
2. Doctors access via time-bound consent stored on-chain.
3. Emergency override logged immutably on-chain.
4. Transparent audit trail combining backend + blockchain.

## 🚀 Next Steps
- Add doctor dashboard in frontend
- Better key management UX (QR / wallet connect)
- Switch audit_db.json → Postgres or MongoDB
- Deploy backend on cloud (e.g. Render/Heroku/Vercel)
