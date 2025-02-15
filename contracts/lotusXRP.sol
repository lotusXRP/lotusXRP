// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title LotusXRP
 * @dev Secure XRP trading platform with TEE attestation
 */
contract LotusXRP is AccessControl, ReentrancyGuard, Pausable {
    // Roles
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    
    // XRP token interface
    IERC20 public immutable xrpToken;
    
    // Trading parameters
    uint256 public constant MIN_TRADE_SIZE = 100 * 1e6; // 100 XRP minimum
    uint256 public constant MAX_TRADE_SIZE = 100000 * 1e6; // 100k XRP maximum
    uint256 public constant TRADE_FEE_BASIS_POINTS = 30; // 0.3% fee
    
    // Platform state
    mapping(address => uint256) public tradingBalances;
    mapping(bytes32 => bool) public executedTrades;
    mapping(address => uint256) public lastTradeTimestamp;
    
    struct Trade {
        address trader;
        uint256 amount;
        bool isBuy;
        uint256 price;
        bytes32 teeAttestationHash;
        bytes signature;
        uint256 timestamp;
    }
    
    // Events
    event TradeExecuted(
        bytes32 indexed tradeId,
        address indexed trader,
        uint256 amount,
        bool isBuy,
        uint256 price,
        uint256 timestamp
    );
    
    event TEEVerified(
        bytes32 indexed attestationHash,
        address indexed trader,
        uint256 timestamp
    );
    
    event BalanceUpdated(
        address indexed trader,
        uint256 newBalance,
        bool isDeposit
    );

    constructor(address _xrpToken, address _admin) {
        require(_xrpToken != address(0), "Invalid XRP token address");
        require(_admin != address(0), "Invalid admin address");
        
        xrpToken = IERC20(_xrpToken);
        
        _setupRole(DEFAULT_ADMIN_ROLE, _admin);
        _setupRole(ADMIN_ROLE, _admin);
    }
    
    /**
     * @dev Execute XRP trade with TEE attestation
     */
    function executeTrade(Trade calldata trade) 
        external 
        nonReentrant 
        whenNotPaused 
        onlyRole(OPERATOR_ROLE) 
        returns (bytes32) 
    {
        // Validate trade parameters
        require(trade.amount >= MIN_TRADE_SIZE, "Trade size too small");
        require(trade.amount <= MAX_TRADE_SIZE, "Trade size too large");
        require(trade.timestamp + 15 minutes > block.timestamp, "Trade expired");
        
        // Generate trade ID
        bytes32 tradeId = keccak256(abi.encode(
            trade.trader,
            trade.amount,
            trade.isBuy,
            trade.price,
            trade.timestamp
        ));
        require(!executedTrades[tradeId], "Trade already executed");
        
        // Verify TEE attestation
        require(
            verifyTEEAttestation(trade.teeAttestationHash, trade.signature),
            "Invalid TEE attestation"
        );
        
        // Calculate fees
        uint256 fee = (trade.amount * TRADE_FEE_BASIS_POINTS) / 10000;
        uint256 netAmount = trade.amount - fee;
        
        if (trade.isBuy) {
            // Handle buy order
            require(
                tradingBalances[trade.trader] >= trade.amount,
                "Insufficient balance"
            );
            tradingBalances[trade.trader] -= trade.amount;
            require(
                xrpToken.transfer(trade.trader, netAmount),
                "XRP transfer failed"
            );
        } else {
            // Handle sell order
            require(
                xrpToken.transferFrom(trade.trader, address(this), trade.amount),
                "XRP transfer failed"
            );
            tradingBalances[trade.trader] += netAmount;
        }
        
        executedTrades[tradeId] = true;
        lastTradeTimestamp[trade.trader] = block.timestamp;
        
        emit TradeExecuted(
            tradeId,
            trade.trader,
            trade.amount,
            trade.isBuy,
            trade.price,
            block.timestamp
        );
        
        return tradeId;
    }
    
    /**
     * @dev Verify TEE attestation signature
     */
    function verifyTEEAttestation(
        bytes32 attestationHash,
        bytes memory signature
    ) 
        internal 
        returns (bool) 
    {
        // TEE verification logic here
        // In production, this would integrate with Google Cloud's TEE verification
        
        emit TEEVerified(
            attestationHash,
            msg.sender,
            block.timestamp
        );
        
        return true;
    }
    
    /**
     * @dev Deposit trading balance
     */
    function deposit() external payable {
        tradingBalances[msg.sender] += msg.value;
        
        emit BalanceUpdated(
            msg.sender,
            tradingBalances[msg.sender],
            true
        );
    }
    
    /**
     * @dev Withdraw trading balance
     */
    function withdraw(uint256 amount) external nonReentrant {
        require(tradingBalances[msg.sender] >= amount, "Insufficient balance");
        
        tradingBalances[msg.sender] -= amount;
        
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");
        
        emit BalanceUpdated(
            msg.sender,
            tradingBalances[msg.sender],
            false
        );
    }
    
    /**
     * @dev Emergency controls
     */
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }
    
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }
    
    /**
     * @dev Allow contract to receive XRP
     */
    receive() external payable {}
}