// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4; // Use a specific version

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol"; // For better ownership management
import "@openzeppelin/contracts/security/ReentrancyGuard.sol"; // Prevent reentrancy

contract AI_Sec_Lotus is Ownable, ReentrancyGuard {

    IERC20 public immutable token; // Immutable for security

    enum TransactionStatus {
        Pending,
        Approved,
        Delayed,
        Rejected
    }

    struct Transaction {
        address user;
        uint256 amount;
        TransactionStatus status;
        bool isSuspicious;
    }

    mapping(uint256 => Transaction) public transactions;
    uint256 public nextTransactionId;

    // Events for off-chain tracking
    event TransactionInitiated(uint256 indexed transactionId, address indexed user, uint256 amount);
    event TransactionStatusChanged(uint256 indexed transactionId, TransactionStatus status, bool isSuspicious);
    event TransactionApproved(uint256 indexed transactionId);
    event TransactionDelayed(uint256 indexed transactionId);
    event TransactionRejected(uint256 indexed transactionId);
    event SuspiciousStatusSet(uint256 indexed transactionId, bool isSuspicious);

    // Custom errors (Solidity 0.8.4+) for better error handling
    error InsufficientBalance(uint256 available, uint256 requested);
    error TransactionNotFound(uint256 transactionId);
    error InvalidTransactionStatus(uint256 transactionId, TransactionStatus currentStatus);
    error Unauthorized();

    // Constructor
    constructor(IERC20 _token) {
        if (address(_token) == address(0)) revert("Invalid Token");
        token = _token;
        nextTransactionId = 1; // Start transaction IDs from 1
    }


    // --- User Functions ---

    function initiateTransaction(uint256 _amount) external nonReentrant {
        if(_amount <= 0 ) revert ("Invalid amount");
        uint256 balance = token.balanceOf(msg.sender);
        if (balance < _amount) revert InsufficientBalance(balance, _amount);

        uint256 transactionId = nextTransactionId++;
        transactions[transactionId] = Transaction({
            user: msg.sender,
            amount: _amount,
            status: TransactionStatus.Pending,
            isSuspicious: false
        });

        emit TransactionInitiated(transactionId, msg.sender, _amount);
    }

    // --- Owner-Only Functions (AI Interaction & Management) ---
    function approveTransaction(uint256 _transactionId) external onlyOwner nonReentrant {
        Transaction storage transaction_ = transactions[_transactionId];
        if(address(transaction_.user) == address(0)) revert TransactionNotFound(_transactionId);
        if (transaction_.status != TransactionStatus.Pending && transaction_.status != TransactionStatus.Delayed) {
            revert InvalidTransactionStatus(_transactionId, transaction_.status);
        }
        if (transaction_.isSuspicious) {
            revert InvalidTransactionStatus(_transactionId, transaction_.status); // Prevent approving suspicious txs
        }

        transaction_.status = TransactionStatus.Approved;
        emit TransactionStatusChanged(_transactionId, TransactionStatus.Approved, false);
        emit TransactionApproved(_transactionId);

        // Perform the token transfer *after* approval and AI check
        if(!token.transferFrom(transaction_.user, address(this), transaction_.amount))
            revert ("transferFrom failed");
    }

    function delayTransaction(uint256 _transactionId) external onlyOwner {
        Transaction storage transaction_ = transactions[_transactionId];
        if(address(transaction_.user) == address(0)) revert TransactionNotFound(_transactionId);
        if (transaction_.status != TransactionStatus.Pending) {
          revert InvalidTransactionStatus(_transactionId, transaction_.status);
        }

        transaction_.status = TransactionStatus.Delayed;
        emit TransactionStatusChanged(_transactionId, TransactionStatus.Delayed, transaction_.isSuspicious);
        emit TransactionDelayed(_transactionId);
    }

    function rejectTransaction(uint256 _transactionId) external onlyOwner {
        Transaction storage transaction_ = transactions[_transactionId];
        if(address(transaction_.user) == address(0)) revert TransactionNotFound(_transactionId);
        if (transaction_.status != TransactionStatus.Pending && transaction_.status != TransactionStatus.Delayed) {
            revert InvalidTransactionStatus(_transactionId, transaction_.status);
        }

        transaction_.status = TransactionStatus.Rejected;
        emit TransactionStatusChanged(_transactionId, TransactionStatus.Rejected, transaction_.isSuspicious); // Keep suspicious flag
        emit TransactionRejected(_transactionId);
        // No token transfer on rejection.
    }

    function setSuspiciousTransaction(uint256 _transactionId, bool _isSuspicious) external onlyOwner {
        Transaction storage transaction_ = transactions[_transactionId];
        if(address(transaction_.user) == address(0)) revert TransactionNotFound(_transactionId);

        transaction_.isSuspicious = _isSuspicious;
        emit SuspiciousStatusSet(_transactionId, _isSuspicious);
        emit TransactionStatusChanged(_transactionId, transaction_.status, _isSuspicious);

        //If not suspicious and transaction is approved complete it
        if(!_isSuspicious && transaction_.status == TransactionStatus.Approved){
          if(!token.transferFrom(transaction_.user, address(this), transaction_.amount))
             revert ("transferFrom failed");
        }
    }


    // --- View Functions ---

    function getTransaction(uint256 _transactionId) external view returns (Transaction memory) {
        return transactions[_transactionId];
    }
    //Added to retrieve the transaction status.
    function getTransactionStatus(uint256 _transactionId) external view returns (TransactionStatus) {
       if (transactions[_transactionId].user == address(0)) {
            revert TransactionNotFound(_transactionId);
        }
        return transactions[_transactionId].status;
    }
}