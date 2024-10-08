const { Wallet, utils } = require('zksync-ethers');
const ethers = require('ethers');
const { HardhatRuntimeEnvironment } = require('hardhat/types');
const HRE = require('hardhat');
const { Deployer } = require('@matterlabs/hardhat-zksync-deploy');
require('dotenv').config();
const { setTimeout } = require('timers/promises');
const deployments = require('./deployments');

const d = process.env.TESTACCT;


async function deployContract(privKey, artifactName, args) {
  const wallet = new Wallet(privKey);
  const deployer = new Deployer(HRE, wallet);
  const artifact = await deployer.loadArtifact(artifactName);
  args.push(wallet.address);
  const contract = await deployer.deploy(artifact, args);
  console.log(`deployed ${artifactName} at address: ${contract.target}`);
  await setTimeout(10000);
  await run('verify:verify', {
    address: contract.target,
    constructorArguments: args,
  });
}

async function deployAll(privKey, zkToken, zkGovernor, auditorAddress) {
  
  const wallet = new Wallet(privKey);
  const deployer = new Deployer(HRE, wallet);
  let initialMintCap = BigInt(10 ** 18) * BigInt(10000000);
  let TokenDistributor = await deployer.loadArtifact('TokenDistributor');
  let tokenDistributor = await deployer.deploy(TokenDistributor, [zkGovernor, zkToken, initialMintCap.toString()]);
  console.log(`deployed TokenDistributor at address: ${tokenDistributor.target}`);
  await setTimeout(3000);

  // deploy program manager factory
  let ProgramManagerFactory = await deployer.loadArtifact('ProgramManagerFactory');
  let programManagerFactory = await deployer.deploy(ProgramManagerFactory, [wallet.address]);
  console.log(`deployed ProgramManagerFactory at address: ${programManagerFactory.target}`);
  await setTimeout(3000);

  //  deploy program distributor
  let ProgramDistributor = await deployer.loadArtifact('ProgramDistributor');
  let programDistributor = await deployer.deploy(ProgramDistributor, [programManagerFactory.target, zkToken]);
  console.log(`deployed ProgramDistributor at address: ${programDistributor.target}`);
  await setTimeout(3000);

  // deploy the award distributor
  let AwardDistributor = await deployer.loadArtifact('AwardDistributor');
  let awardDistributor = await deployer.deploy(AwardDistributor, [zkToken]);
  console.log(`deployed AwardDistributor at address: ${awardDistributor.target}`);
  await setTimeout(3000);

  // deploy the award manager factory
  let AwardManagerFactory = await deployer.loadArtifact('AwardManagerFactory');
  let awardManagerFactory = await deployer.deploy(AwardManagerFactory, [
    awardDistributor.target,
    programDistributor.target,
    zkToken,
  ]);
  console.log(`deployed AwardManagerFactory at address: ${awardManagerFactory.target}`);
  await setTimeout(3000);

  const fundingAllowance = BigInt(2628000);
  await programManagerFactory.init(
    programDistributor.target,
    tokenDistributor.target,
    zkGovernor,
    zkToken,
    fundingAllowance
  );
  console.log('Initialized ProgramManagerFactory');

  // create a program manager
  await programManagerFactory.createProgramManager(wallet.address);
  let programManagerAddress = (await programManagerFactory.programManagers(wallet.address));
  console.log('program manager address: ', programManagerAddress);
  await setTimeout(3000);

  // deploys Oracles and KYC NFT
  let KYCNFT = await deployer.loadArtifact('KYCNFT');
  let kycNFT = await deployer.deploy(KYCNFT, ['KYCNFT', 'KYC']);
  console.log(`deployed KYCNFT at address: ${kycNFT.target}`);
  await setTimeout(3000);

  let Oracle = await deployer.loadArtifact('Oracles');
  let oracle = await deployer.deploy(Oracle, [kycNFT.target, auditorAddress]);
  console.log(`deployed Oracles at address: ${oracle.target}`);
  await setTimeout(3000);

  // deploy the Claims contracts
  let Claims = await deployer.loadArtifact('DelegatedClaimCampaigns');
  let claims = await deployer.deploy(Claims, ['ClaimCampaigns', '1', []]);
  console.log(`deployed Claims at address: ${claims.target}`);

  let Claimer = await deployer.loadArtifact('ClaimIntermediary');
  let claimer = await deployer.deploy(Claimer, [claims.target, zkToken, deployments.programDistributor]);
  console.log(`deployed Claimer at address: ${claimer.target}`);

  await run('verify:verify', {
    address: deployments.tokenDistributor,
    constructorArguments: [zkGovernor, zkToken, initialMintCap.toString()],
  });

  await run('verify:verify', {
    address: deployments.programManagerFactory,
    constructorArguments: [wallet.address],
  });


  await run('verify:verify', {
    address: deployments.programDistributor,
    constructorArguments: [deployments.programManagerFactory, zkToken],
  });

  await run('verify:verify', {
    address: deployments.awardDistributor,
    constructorArguments: [zkToken],
  });

  await run('verify:verify', {
    address: deployments.awardManagerFactory,
    constructorArguments: [deployments.awardDistributor, deployments.programDistributor, zkToken],
  });

  await run('verify:verify', {
    address: deployments.programManager,
    constructorArguments: [wallet.address, deployments.programDistributor, zkToken],
  });

  await run('verify:verify', {
    address: deployments.kycNFT,
    constructorArguments: ['KYCNFT', 'KYC'],
  });

  await run('verify:verify', {
    address: deployments.oracle,
    constructorArguments: [deployments.kycNFT, auditorAddress],
  });
  await run('verify:verify', {
    address: deployments.claims,
    constructorArguments: ['ClaimCampaigns', '1', []],
  });
  await run('verify:verify', {
    address: deployments.claimer,
    constructorArguments: [deployments.claims, zkToken, deployments.programDistributor],
  });
}

const zkToken = '0x69e5DC39E2bCb1C17053d2A4ee7CAEAAc5D36f96';
const zkGovernor = '0x0d9DD6964692a0027e1645902536E7A3b34AA1d7';
const auditor = '0x0d9DD6964692a0027e1645902536E7A3b34AA1d7'

deployAll(d, zkToken, zkGovernor, auditor);
