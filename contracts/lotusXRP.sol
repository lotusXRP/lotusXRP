// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@flare/StateConnector.sol"; // Hypothetical import, adjust per Flare docs

contract LotusXRP is ERC20 {
    address public owner;
    StateConnector public stateConnector; // Flare's State Connector
    mapping(bytes32 => bool) public processedTxs; // Track XRPL txs
    mapping(address => string) public refundAddresses; // Flare -> XRPL address
    uint256 public dailyMintCap = 100 * 10**18; // 100 XRP/day (18 decimals)
    uint256 public mintedToday;
    uint256 public lastReset;

    event MintRequest(bytes32 txHash, address user, uint256 amount);
    event BurnRequest(address user, uint256 amount, string xrplAddress);

    constructor(address _stateConnector) ERC20("LotusXRP", "LXRP") {
        owner = msg.sender;
        stateConnector = StateConnector(_stateConnector);
        lastReset = block.timestamp;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    // Reset daily cap every 24 hours
    function resetDailyCap() internal {
        if (block.timestamp >= lastReset + 1 days) {
            mintedToday = 0;
            lastReset = block.timestamp;
        }
    }

    // Mint LotusXRP after verifying XRPL lock
    function mint(bytes32 xrplTxHash, uint256 amount) external {
        resetDailyCap();
        require(!processedTxs[xrplTxHash], "Tx already processed");
        require(mintedToday + amount <= dailyMintCap, "Daily cap exceeded");

        // Request State Connector to verify XRPL tx (simplified)
        bool isVerified = stateConnector.requestVerification(xrplTxHash);
        require(isVerified, "XRPL tx not verified");

        processedTxs[xrplTxHash] = true;
        mintedToday += amount;
        _mint(msg.sender, amount);
        emit MintRequest(xrplTxHash, msg.sender, amount);
    }

    // Burn LotusXRP and log XRPL refund address
    function burn(uint256 amount, string memory xrplAddress) external {
        _burn(msg.sender, amount);
        refundAddresses[msg.sender] = xrplAddress;
        emit BurnRequest(msg.sender, amount, xrplAddress);
    }

    // Manual unlock by owner (custodial for now)
    function unlockXRPL(address user) external onlyOwner {
        string memory xrplAddr = refundAddresses[user];
        require(bytes(xrplAddr