const hre = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying with", deployer.address);

  // Deploy AuditLogger
  const AuditLogger = await hre.ethers.getContractFactory("AuditLogger");
  const al = await AuditLogger.deploy();
  await al.waitForDeployment();
  const alAddr = await al.getAddress();
  console.log("AuditLogger deployed to:", alAddr);

  // Deploy ConsentManager with audit logger address
  const ConsentManager = await hre.ethers.getContractFactory("ConsentManager");
  const cm = await ConsentManager.deploy(alAddr);
  await cm.waitForDeployment();
  const cmAddr = await cm.getAddress();
  console.log("ConsentManager deployed to:", cmAddr);

  // write artifacts
  const outDir = path.join(__dirname, "..", "deployments");
  if (!fs.existsSync(outDir)) fs.mkdirSync(outDir);

  const alArtifact = await hre.artifacts.readArtifact("AuditLogger");
  fs.writeFileSync(path.join(outDir, "AuditLogger.json"), JSON.stringify({
    address: alAddr,
    abi: alArtifact.abi
  }, null, 2));

  const cmArtifact = await hre.artifacts.readArtifact("ConsentManager");
  fs.writeFileSync(path.join(outDir, "ConsentManager.json"), JSON.stringify({
    address: cmAddr,
    abi: cmArtifact.abi
  }, null, 2));

  console.log("Wrote deployments/ AuditLogger.json & ConsentManager.json");
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
