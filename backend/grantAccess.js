// backend/grantAccess.js (correct param order)
require('dotenv').config();
const { ethers } = require('ethers');
const fs = require('fs');
const path = require('path');

const CONSENT_JSON = require('../medchain-blockchain/deployments/ConsentManager.json');
const CONSENT_ADDR = CONSENT_JSON.address;
const CONSENT_ABI = CONSENT_JSON.abi;

const AMOY_RPC_URL = process.env.AMOY_RPC_URL;
const PRIVATE_KEY = process.env.DEPLOYER_PRIVATE_KEY;

function checkHexAddress(addr) {
  const s = String(addr).trim();
  if (!/^0x[a-fA-F0-9]{40}$/.test(s)) throw new Error("Invalid hex address");
  return ethers.getAddress(s);
}

async function main() {
  const provider = new ethers.JsonRpcProvider(AMOY_RPC_URL);
  const wallet = new ethers.Wallet(PRIVATE_KEY, provider);

  const grantee = checkHexAddress(process.env.TEST_GRANTEE || wallet.address);
  const fileCid = String(process.env.TEST_FILECID || "demoFileCid");
  const encKeyCid = String(process.env.TEST_ENCKEYCID || "demoEncKeyCid");
  const expiry = parseInt(process.env.TEST_EXPIRY || "600", 10);

  console.log("Granting (ENS-free) ->", { fileCid, grantee, expiry, encKeyCid });

  const iface = new ethers.Interface(CONSENT_ABI);
  const data = iface.encodeFunctionData("grantAccess", [fileCid, grantee, expiry, encKeyCid]);

  const tx = await wallet.sendTransaction({ to: CONSENT_ADDR, data });
  const receipt = await tx.wait();

  console.log("✅ Tx sent:", tx.hash, "block:", receipt.blockNumber);

  // update audit_db.json
  const dbPath = path.join(__dirname, 'audit_db.json');
  let db = { audit: [], grants: [] };
  if (fs.existsSync(dbPath)) db = JSON.parse(fs.readFileSync(dbPath, 'utf8'));
  db.grants.push({ patient: wallet.address, fileCid, grantee, encKeyCid, expiry, txHash: tx.hash, blockNumber: receipt.blockNumber, ts: Date.now() });
  fs.writeFileSync(dbPath, JSON.stringify(db, null, 2));
}

main().catch(err => {
  console.error("grantAccess.js err:", err);
  process.exit(1);
});
