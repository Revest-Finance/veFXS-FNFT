import { Contract, providers, utils, ethers } from 'ethers';

const TOKEN_CONFIGS = {
  WETH: {
    // https://etherscan.io/token/0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2?a=0x2f0b23f53734252bda2277357e97e1517d6b042a
    address: '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2',
    decimals: 18,
    tokenHolder: '0x2f0b23f53734252bda2277357e97e1517d6b042a',
  },
};

const FXS_ADDRESS  = '0x3432b6a60d23ca0dfca7761b7ab56459d9c964d0'

const fxsWhaleAddress =  '0xd53E50c63B0D549f142A2dCfc454501aaA5B7f3F'

const user = '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266'

type SetBalanceParams = {
  symbol: 'WETH';
  amount: string;
  address: string;
  provider: providers.JsonRpcProvider;
};

type SetUpParams = {
    provider: providers.JsonRpcProvider;
}

const setUpEnvi = async({
    provider
}: SetUpParams) => {
    const fxsABI = [
        //Transfer
        'function transfer(recipient, amount) public virtual override returns(bool)'
    ]

    const fxsContract = new Contract(FXS_ADDRESS, fxsABI, provider);

    // Impersonate the token holder
    await provider.send('anvil_impersonateAccount', [fxsWhaleAddress]);

    // Get the token holder signer
    const signer = await provider.getSigner(fxsWhaleAddress);

    // Connect signed with the contract
    const contractWithSigner = fxsContract.connect(signer);

    // Tranfer funds
    const unitAmount = utils.parseUnits('1', 18);
    await contractWithSigner.transfer(user, unitAmount);
}

const setBalance = async ({
  symbol,
  amount,
  address: tokenReceiver,
  provider,
}: SetBalanceParams) => {
  const tokenConfig = TOKEN_CONFIGS[symbol];

  const { address: contractAddress, decimals, tokenHolder } = tokenConfig;

  const contractAbi = [
    // Get the account balance
    'function balanceOf(address) view returns (uint)',

    // Send some of your tokens to someone else
    'function transfer(address to, uint amount)',
  ];
  const contract = new Contract(contractAddress, contractAbi, provider);

  // Fund token holder so they can make the transaction
  await provider.send('hardhat_setBalance', [
    tokenHolder,
    utils.parseEther('1.0').toHexString().replace('0x0', '0x'),
  ]);

  // Impersonate the token holder
  await provider.send('anvil_impersonateAccount', [tokenHolder]);

  // Get the token holder signer
  const signer = await provider.getSigner(tokenHolder);

  // Connect signed with the contract
  const contractWithSigner = contract.connect(signer);

  // Tranfer funds
  const unitAmount = utils.parseUnits(amount, decimals);
  await contractWithSigner.transfer(tokenReceiver, unitAmount);

  await provider.send('anvil_stopImpersonatingAccount', [tokenHolder]);
};

async function main() {
  const provider = new ethers.providers.JsonRpcProvider();

  await setUpEnvi({
    provider,
  });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});