// backend/verifyConsent.js
require("dotenv").config();
const { ethers } = require("ethers");

const CONSENT_JSON = require("../medchain-blockchain/deployments/ConsentManager.json");
const CONSENT_ADDR = CONSENT_JSON.address;
const CONSENT_ABI = CONSENT_JSON.abi;

const AMOY_RPC_URL = process.env.AMOY_RPC_URL;
const provider = new ethers.JsonRpcProvider(AMOY_RPC_URL);

async function main() {
  const grantee = process.env.TEST_GRANTEE;
  const fileCid = process.env.TEST_FILECID;

  if (!grantee || !fileCid) {
    throw new Error("Set TEST_GRANTEE and TEST_FILECID in your .env file before running verifyConsent.js");
  }

  console.log(`🔎 Checking consent for grantee=${grantee}, fileCid=${fileCid}`);

  const cm = new ethers.Contract(CONSENT_ADDR, CONSENT_ABI, provider);

  const consent = await cm.getConsent(fileCid, grantee);

  console.log("✅ On-chain consent result:");
  console.log({
    patient: consent.patient,
    grantee: consent._grantee,
    expiresAt: Number(consent.expiresAt),
    encKeyCid: consent.encKeyCid,
    active: consent.active
  });

  const expiryDate = new Date(Number(consent.expiresAt) * 1000);
  console.log("⏳ Expires at:", expiryDate.toISOString());
}

main().catch((err) => {
  console.error("verifyConsent.js error:", err);
  process.exit(1);
});
