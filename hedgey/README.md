# Repo for ZkSync Token Accountability Program for Token Awards Distribution by Hedgey Finance

# Architecture overview: 

   The Hedgey Distribution Program for ZkToken Accountability is meant to allow anyone to create a token award for themselves, or play the role of Program Manager, and distribute out tokens to a group of recipients. The Program Manager contract is allowed to mint tokens from the TokenDistributor contract after a successful proposal to the DAO. Tokens minted to the Program Manager can only be minted for up to a set funding need in the future. Additionally, the Program Manager can set in motion all of their distribution plans to specific recipients ahead of this time - allowing enhanced transparency before any tokens are distributed and the proposal passes. The Program Manager utilizes a ProgramDistributor.sol ERC721 Contract to manage the distributions effectively and transparently to each recipient. The recipients can claim tokens on the predefined schedule, and either pass along tokens to themselves, to their protocol users, or to other token awards recipients. This allows for top level accountability by the Program Manager, but lower level flexibility and real time automation necessary to execute a well performing token accountability and rewards program. 

 # Onchain Scenario Example (at ZKsnyc testnet)

## Contracts deployed to testnet
  tokenDistributor: `0x76f0E305a3078a026DE016A3212649BA6ACC3688`   
  programManagerFactory: `0x39E21d40AE739cA860F07c51d1Ec89B9F343b3C4`   
  programDistributor: `0x4EC6f3F01A405507BE3D118Ac7F4E8762fF80597`    
  awardDistributor: `0x6EC719Fb0cc78c4622cA7e0984E6a1101B33c0cB`    
  awardManagerFactory: `0xcb5D0dE0875849bd296D02DB18839f4938F48F99`   
  programManager: `0xf3eF16FE138c46e209e66CEE2Da8f0Ef3bec2D81`      
  kycNFT: `0x24ea948A3C0A4C29FB4895DE20a2097BD96391D9`      
  oracle: `0x3BC868388649918982b0b87dF21F22226E94C473`       
  HedgeyclaimsContract: `0xdA4E6EE0D5665dF7E19F6EF9Eb9AE25E1772299e`       
  claimer test contract: `0xa0fc01aA15f98565e79C39F3E9290A0054B88d9C`      
  zkToken: `0x69e5DC39E2bCb1C17053d2A4ee7CAEAAc5D36f96`    
  zkGovernor: `0x0d9DD6964692a0027e1645902536E7A3b34AA1d7`   
  awardManagerB: `0x1Ee6f8e4C970B389373639f8179Ebe41E339a7e5`    
  awardManagerE: `0xfC429eDa51f7013014Afb5041695132Bf5dB3A9B`   


  ## **Pre Proposal Setup:**

1. Bob wanted to setup a new program for token awards. Bob used the program manager factory to create a new program manager contract for himself.  https://sepolia.explorer.zksync.io/tx/0x1c3a8505b88c9043a8f9c7b7b4fee9b09d24fa76767d1d10c807d4175f566303
2. Then Bob created the stream / algo for awarding tokens to 3 recipients. All 3 need to have a KYC NFT to claim tokens https://sepolia.explorer.zksync.io/tx/0x6e8aaf272418f35e48be673c58643db23c0588394c46a95babc0c23e737375fd#eventlog
    1. One of the recipients was a base wallet, receiving 1,000 tokens over 3 months; **0xe31D847B47465cC2745319dAc9E0c6ac711cA10b**
    2. One of the recipients was an Award Manager contract, which can pull tokens and distribute them to other recipients. Being sent 25,000 tokens over 3 months. This Award Manager is at address: **0x1Ee6f8e4C970B389373639f8179Ebe41E339a7e5**. 
    3. The Final recipient was a ‘protocol’, which used a specially crafted contract that will allow it to redeem awarded tokens, and immediately create a merkle tree based claim using the Hedgey ClaimCampaigns contract; allowing tokens to be passed directly from contract to contract without going to a gnosis safe or hot wallet intermediary. This award is for 100,000 tokens over 3 months. This contract is located at; **0xa0fc01aA15f98565e79C39F3E9290A0054B88d9C**.
3. Then Bob reviewed and finalized the program by initializing the setup, which means that no new awards can be created. This way there is full transparency and the DAO can review where tokens are being allocated to, and under what terms. https://sepolia.explorer.zksync.io/tx/0x2e68f22525515b09bf9cc8e78063228e4323972bc09e5f09d5c008cca93c528d#overview   
     

## **Proposal**: 

1. Bob proposed to the DAO his program. This proposal would allow the TokenDistributor contract to have the Minter role for the Token. 
    1. It also immediately approved Bob’s awards program. 
    2. The initial cap was set high enough to cover bob’s 126k token requirements.
        1. This cap can always be set higher by the DAO. It should be updated with each new proposal. 
    3. The program manager contract allows the DAO to at anytime cancel the entire program, pulling all of the tokens out of the manager contract back to the DAO contract, and deleting the awards streams. 
2. The DAO approved his request and proposal was executed onchain https://sepolia.explorer.zksync.io/tx/0xd71a6f84b23fddfdd3f5849d941d5b24ba3f0f49e77785a81e4e9aaf62efe105#eventlog
   Prposal link; https://www.tally.xyz/gov/testnet-zksync/proposal/24097557120493254014729317328656316770406758737014803952996743543821234507526    


      
 ##  **The Award Program**

1. With the Program live, Bob first funded his Program Manager with the approved allotment of tokens - **which is 1 months worth of tokens** (in this case, something set initially and can be changed by the DAO at anytime) https://sepolia.explorer.zksync.io/tx/0xcbfda8cb31c8d1625c7074174e53c08a166f80a30fc927575428c17ad2bd4d8c#overview
    1. Because the Token Distributor has the Minter Role - this function called the distributeTokens function which mints tokens directly from the zkToken, and delivers them to the Program Manager. 
    2. Now recipients will be able to redeem their awards as they are streamed to them. 
2. This program required that the awardees have a KYC NFT in their possession before they could redeem anything. 
    1. Recipient 0xe31D847B47465cC2745319dAc9E0c6ac711cA10b attempted to redeem tokens without the KYC NFT, and although the tx did not revert, no tokens were delivered because they had not met the requirement.  https://sepolia.explorer.zksync.io/tx/0xb6fbc3515d3e72ba260035f98859aa61f7becf5ca55f32b2ab5dede7c4b5987b#overview
    2. After recipient 0xe31D847B47465cC2745319dAc9E0c6ac711cA10b  Did receive their KYC NFT, they then redeemed tokens properly, and were able to claim the correct amount; https://sepolia.explorer.zksync.io/tx/0xb351d9ffc95953b071211850d3702b8bb9b91be0542ee6de640e32041f44cad8
    3. Then the recipient created several forwarding addresses so that tokens would automatically be split upon redemption in equal proportion to the ownership of the award; https://sepolia.explorer.zksync.io/tx/0xcb518f22d7b69e1f00faa26e10716fd03d55e1d677805eb9b9d1f2c620652149 
        1. when redeeming a small portion, we can see the split of the tokens to each forward address with the appropriate allocations, directly transferring https://sepolia.explorer.zksync.io/tx/0xe053f028748597c58f0976957d75b60f3c1e67b060f8302a591d1ff9ab71dc6c
3. The Protocol with special claim functionality received its KYC NFT and prepared to create a new claims setup for all of its protocol users (having created a rewards / points system for users on their platform to be compensated and rewarded)
    1. Then it created a merkle tree claim for its claimers, using the claimRewardsWithData function; https://sepolia.explorer.zksync.io/tx/0x6c14c1db4d6c5cb1c6fa3beedde60da01898806214a4a6d8463afdbbc8ead2ba
4. The final recipient redeems some tokens, allowing its recipients to claim from its balances AFTER it received its [KYC NFT](https://sepolia.explorer.zksync.io/tx/0x86237ffc37d24bc64bb9a1a71fb99fda55a63601d5de0568828c27b76e414950)  https://sepolia.explorer.zksync.io/tx/0x6aea9c65bb6dbc7ff594a3a2ca82e97eea0426d98f698666bff47a2d02af1cc2, https://sepolia.explorer.zksync.io/tx/0x553d1fc57c42a359c880e01150141caf9592623c5445f7d1503e3a8dd6d428aa (required twice to fund both its recipients)
    1. This let the recipients who had received their Award Distributor NFTs to now pull tokens from this Award Manager contract directly (instead of the Program Manager). Where this Award Manager, named Alice, now controls distributing token awards to other groups and individuals directly. 
    2. For the first recipient, Alice disbursed tokens on behalf of the recipient, because the manager was approved to redeem on its behalf;  https://sepolia.explorer.zksync.io/tx/0xef86c16de2164cd9b1c4614e6836936ef710639c6b909803897c1b1041ee10f5
    3. The second recipient was a sub-manager, another Award Manager itself, named Charles, which redeemed its tokens so that its two token award recipients could redeem their allocations.
