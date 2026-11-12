# Escrow

A simple two-party ERC-20 escrow smart contract written in Solidity and built with Foundry. A seller sets the terms, the buyer locks tokens in the contract, and the funds are then either released to the seller or refunded to the buyer.

> ⚠️ Learning project, deployed on Sepolia testnet only. It is **not audited** and should not be used with real funds.

## Why an escrow?

When two parties don't trust each other, someone has to pay or deliver first. The contract acts as a neutral middleman: it holds the tokens, and the code decides where they can go.

## How it works

**Roles**
- **Seller**: deploys the contract and sets the buyer, token, and amount.
- **Buyer**: approves and deposits the tokens, and can release them to the seller.

**Phases**

```
Waiting  ->  Funded  ->  Complete
```

**Flow**
1. The seller deploys `Escrow(buyer, token, amount)`.
2. The buyer calls `approve(escrow, amount)` on the token.
3. The buyer calls `deposit()`, and the tokens are locked (phase: `Funded`).
4. One of two endings:
   - `releaseFunds()` (buyer only): tokens go to the seller.
   - `refund()` (seller only): tokens go back to the buyer.
5. The phase becomes `Complete`, and funds can only leave once.

## Contract reference

| Function | Caller | Phase required | Effect |
|---|---|---|---|
| `deposit()` | Buyer | Waiting | Pulls `amount` tokens into the escrow |
| `releaseFunds()` | Buyer | Funded | Sends tokens to the seller |
| `refund()` | Seller | Funded | Returns tokens to the buyer |

**Public state:** `buyer`, `seller`, `token`, `amount`, `phase`

**Events:** `Funded`, `Given`

**Errors:** `ZeroAddr`, `ZeroAmt`, `NotOwner` (buyer equals seller), `WrongPhase`

## Security design
- **Checks-effects-interactions:** the phase is updated before any token transfer.
- **`SafeERC20`** for all token transfers.
- **Immutable** parties, token, and amount, so they can't change after deployment.
- **Constructor validation:** rejects zero addresses, a zero amount, and buyer == seller.

## Known limitations
- If the buyer never releases, the seller's only option is to refund, and there is no dispute resolution.
- Fee-on-transfer and rebasing tokens are not supported.
- The buyer must verify the seller's chosen token and amount before depositing.

## Deployments (Sepolia)

| Contract | Address |
|---|---|
| Token (RED) | `0xb8b401e1C72423Ff4050cb4044cA70f894Fb646F` |
| Escrow | `0x2e0b8080b708f98F535cfA0AE0A5a60EdCfA60f9` |

## Getting started

**Requirements:** [Foundry](https://book.getfoundry.sh/getting-started/installation)

```bash
git clone <your-repo-url>
cd escrow
forge install
forge build
```

## Test

```bash
forge test -vv
```

## Deploy

```bash
export BUYER_ADDRESS=0x...
export RPC_URL=<your_sepolia_rpc>

# dry run
forge script script/DeployEscrow.s.sol --rpc-url $RPC_URL --account <keystore_name>

# real deployment
forge script script/DeployEscrow.s.sol --rpc-url $RPC_URL --account <keystore_name> --broadcast
```

Keys are handled with Foundry keystores (`cast wallet import <name> --interactive`), never raw private keys.

## Interact

```bash
# buyer approves the escrow
cast send <TOKEN> "approve(address,uint256)" <ESCROW> $(cast to-wei 100) --rpc-url $RPC_URL --account buyer

# buyer deposits
cast send <ESCROW> "deposit()" --rpc-url $RPC_URL --account buyer

# check the phase (0 = Waiting, 1 = Funded, 2 = Complete)
cast call <ESCROW> "phase()(uint8)" --rpc-url $RPC_URL

# release (buyer) or refund (seller)
cast send <ESCROW> "releaseFunds()" --rpc-url $RPC_URL --account buyer
cast send <ESCROW> "refund()" --rpc-url $RPC_URL --account deployer
```

## Roadmap
- [ ] Custom errors for access control, instead of `require` strings
- [ ] Separate `Released` and `Refunded` events
- [ ] Arbiter role and dispute resolution
- [ ] Deadline-based auto-refund
- [ ] Source verification on Etherscan
- [ ] Self-audit and fuzz tests

## Author
Dev Shrimankar: [GitHub](https://github.com/dev45221904)

## License
See `LICENSE`.