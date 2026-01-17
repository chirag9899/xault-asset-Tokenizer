# Xault Asset Tokenizer

UUPS-upgradeable ERC20 token implementation for tokenized financial assets. Built with OpenZeppelin's upgradeable contracts and Foundry.

## Project Structure

```
.
├── src/
│   ├── AssetToken.sol      # V1 implementation with UUPS upgradeability
│   └── AssetTokenV2.sol     # V2 implementation with pause functionality
├── test/
│   └── AssetToken.t.sol     # Comprehensive test suite
├── script/
│   └── DeployAssetToken.s.sol  # Deployment script
└── lib/
    └── openzeppelin-contracts-upgradeable/  # OpenZeppelin upgradeable contracts
```

## Features

### V1 (AssetToken)
- ERC20 with UUPS upgradeability
- Role-based access control (DEFAULT_ADMIN_ROLE, MINTER_ROLE)
- Max supply cap with custom error
- Event emission for minting

### V2 (AssetTokenV2)
- Inherits V1 functionality
- Adds pause/unpause for transfers
- Storage layout compatible with V1

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) (latest version)
- Git

## Setup

1. **Clone the repository** (if applicable):
   ```bash
   git clone <repository-url>
   cd xault-Tokenizer
   ```

2. **Install dependencies**:
   ```bash
   forge install
   ```

   This will install:
   - `forge-std` - Foundry standard library
   - `openzeppelin-contracts-upgradeable` - OpenZeppelin upgradeable contracts

3. **Build the project**:
   ```bash
   forge build
   ```

## Testing

Run the complete test suite:

```bash
forge test
```

Run with verbose output:

```bash
forge test -vvv
```

Run a specific test:

```bash
forge test --match-test test_CompleteUpgradeLifecycle
```

### Test Coverage

The test suite covers the complete upgrade lifecycle:

1. Deploy V1 via ERC1967Proxy with 1M max supply
2. Mint 100 tokens and verify balance
3. Deploy V2 and execute upgrade
4. Verify state persistence after upgrade
5. Test pause functionality
6. Access control enforcement
7. Max supply enforcement

## Deployment

### Local Testnet Deployment

1. **Start a local Anvil node**:
   ```bash
   anvil
   ```

2. **Set environment variables**:
   Create a `.env` file:
   ```bash
   PRIVATE_KEY=<your_private_key>
   ADMIN_ADDRESS=<admin_address>
   MAX_SUPPLY=1000000000000000000000000  # 1M tokens (in wei)
   ```

3. **Deploy the contract**:
   ```bash
   forge script script/DeployAssetToken.s.sol:DeployAssetToken \
     --rpc-url http://localhost:8545 \
     --broadcast \
     --verify
   ```

### Mainnet/Testnet Deployment

For mainnet or testnet deployment:

```bash
forge script script/DeployAssetToken.s.sol:DeployAssetToken \
  --rpc-url <RPC_URL> \
  --broadcast \
  --verify \
  --etherscan-api-key <ETHERSCAN_API_KEY>
```

## Manual Interaction (CLI)

After deployment, you can interact with the contract using `cast` (Foundry's CLI tool):

### Check Contract Info
```bash
# Get max supply
cast call <PROXY_ADDRESS> "maxSupply()(uint256)"

# Get total supply
cast call <PROXY_ADDRESS> "totalSupply()(uint256)"

# Get balance
cast call <PROXY_ADDRESS> "balanceOf(address)(uint256)" <USER_ADDRESS>
```

### Mint Tokens (as minter)
```bash
# Mint 100 tokens to a user
cast send <PROXY_ADDRESS> \
  "mint(address,uint256)" \
  <USER_ADDRESS> \
  100000000000000000000 \
  --private-key <MINTER_PRIVATE_KEY> \
  --rpc-url <RPC_URL>
```

### Grant Minter Role (as admin)
```bash
# Grant MINTER_ROLE to an address
cast send <PROXY_ADDRESS> \
  "grantRole(bytes32,address)" \
  0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6 \
  <MINTER_ADDRESS> \
  --private-key <ADMIN_PRIVATE_KEY> \
  --rpc-url <RPC_URL>
```

### Upgrade to V2 (as admin)
```bash
# First deploy V2 implementation
forge create src/AssetTokenV2.sol:AssetTokenV2 \
  --rpc-url <RPC_URL> \
  --private-key <PRIVATE_KEY>

# Then upgrade the proxy
cast send <PROXY_ADDRESS> \
  "upgradeToAndCall(address,bytes)" \
  <V2_IMPLEMENTATION_ADDRESS> \
  $(cast calldata "initializeV2()") \
  --private-key <ADMIN_PRIVATE_KEY> \
  --rpc-url <RPC_URL>
```

### Pause Contract (as admin, after V2 upgrade)
```bash
cast send <PROXY_ADDRESS> \
  "pause()" \
  --private-key <ADMIN_PRIVATE_KEY> \
  --rpc-url <RPC_URL>
```

## Storage Layout Verification

Storage safety is ensured through OpenZeppelin v5's ERC-7201 Namespaced Storage pattern:

**V1 Storage:**
- `ERC20Upgradeable` → `openzeppelin.storage.ERC20` namespace
- `AccessControlUpgradeable` → `openzeppelin.storage.AccessControl` namespace  
- `maxSupply` → contract's own storage slot

**V2 Storage:**
- Inherits all V1 storage
- Adds `PausableUpgradeable` → `openzeppelin.storage.Pausable` namespace
- No new state variables added

Each namespace uses isolated storage locations calculated as `keccak256(namespace) - 1`, preventing collisions. V2 only adds functionality through the Pausable namespace without modifying existing storage layout.

Tests verify state persistence (balances, roles, maxSupply) after upgrade.

## Security

- Only `DEFAULT_ADMIN_ROLE` can upgrade the contract
- Initializer modifier prevents re-initialization
- Max supply enforced to prevent unlimited minting
- Pause mechanism for emergency stops (V2)
- Storage layout safe for upgrades

## Deployment Notes

After deployment, save these addresses:
- V1 Implementation address (logic contract)
- Proxy address (users interact with this)
- V2 Implementation address (after upgrade)

## Upgrade Process

1. Deploy new implementation (V2)
2. Call `upgradeToAndCall()` on the proxy with:
   - New implementation address
   - Encoded `initializeV2()` call
3. Verify upgrade was successful
4. Test new functionality

## License

MIT

## Contact

For questions or issues, contact: hiring@xaults.com
