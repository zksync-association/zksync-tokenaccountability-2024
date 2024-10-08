require('@matterlabs/hardhat-zksync-solc');
require('@matterlabs/hardhat-zksync-deploy');
require('@matterlabs/hardhat-zksync-verify');
require('@matterlabs/hardhat-zksync-ethers');
require('dotenv').config();

module.exports = {
  zksolc: {
    version: 'latest',
    compilerSource: 'binary',
    settings: {
      enableEraVMExtensions: false, 
      optimizer: {
        enabled: true, // optional. True by default
        mode: '3', // optional. 3 by default, z to optimize bytecode size
      },
    },
  },
  defaultNetwork: 'zkTestnet',
  networks: {
    zkTestnet: {
      url: 'https://sepolia.era.zksync.dev',
      ethNetwork: 'sepolia',
      zksync: true,
      accounts: [process.env.TESTACCT],
      verifyURL: 'https://explorer.sepolia.era.zksync.dev/contract_verification',
    },
    zkSync: {
      url: 'https://mainnet.era.zksync.io',
      ethNetwork: 'mainnet',
      zksync: true,
      accounts: [process.env.DEPLOYER],
      verifyURL: 'https://zksync2-mainnet-explorer.zksync.io/contract_verification',
    },
  },
  solidity: '0.8.24',
};
