import React, { useState, useEffect } from 'react';
import { ethers } from 'ethers';
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Alert, AlertDescription } from '@/components/ui/alert';
import { Wallet, RefreshCw, Send, ShieldAlert } from 'lucide-react';

const Web3Interface = () => {
  const [account, setAccount] = useState('');
  const [provider, setProvider] = useState(null);
  const [signer, setSigner] = useState(null);
  const [contract, setContract] = useState(null);
  const [amount, setAmount] = useState('');
  const [transactions, setTransactions] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  // Contract ABI - Replace with your actual ABI
  const CONTRACT_ADDRESS = '0xYourContractAddress';
  const CONTRACT_ABI = [
    "function initiateTransaction(uint256 _amount) external",
    "function getTransaction(uint256 _transactionId) external view returns (tuple(address user, uint256 amount, uint8 status, bool isSuspicious))",
    "function getTransactionStatus(uint256 _transactionId) external view returns (uint8)",
    "event TransactionInitiated(uint256 indexed transactionId, address indexed user, uint256 amount)"
  ];

  // Initialize Web3 connection
  const initializeWeb3 = async () => {
    try {
      if (window.ethereum) {
        const web3Provider = new ethers.providers.Web3Provider(window.ethereum);
        setProvider(web3Provider);

        const accounts = await window.ethereum.request({
          method: 'eth_requestAccounts'
        });
        setAccount(accounts[0]);

        const web3Signer = web3Provider.getSigner();
        setSigner(web3Signer);

        const contractInstance = new ethers.Contract(
          CONTRACT_ADDRESS,
          CONTRACT_ABI,
          web3Signer
        );
        setContract(contractInstance);

        // Listen for account changes
        window.ethereum.on('accountsChanged', (accounts) => {
          setAccount(accounts[0]);
        });

        // Listen for chain changes
        window.ethereum.on('chainChanged', (_chainId) => {
          window.location.reload();
        });
      } else {
        setError('Please install MetaMask or another Web3 wallet');
      }
    } catch (err) {
      setError(err.message);
    }
  };

  // Connect wallet
  const connectWallet = async () => {
    try {
      setLoading(true);
      await initializeWeb3();
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  // Initiate transaction
  const handleTransaction = async () => {
    try {
      setLoading(true);
      setError('');

      if (!contract || !amount) {
        throw new Error('Please connect wallet and enter amount');
      }

      const parsedAmount = ethers.utils.parseEther(amount);
      const tx = await contract.initiateTransaction(parsedAmount);
      await tx.wait();

      // Listen for transaction event
      contract.on('TransactionInitiated', (transactionId, user, amount) => {
        setTransactions(prev => [...prev, {
          id: transactionId.toString(),
          user,
          amount: ethers.utils.formatEther(amount),
          status: 'Pending'
        }]);
      });

      setAmount('');
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  // Refresh transactions
  const refreshTransactions = async () => {
    try {
      setLoading(true);
      const updatedTransactions = await Promise.all(
        transactions.map(async (tx) => {
          const status = await contract.getTransactionStatus(tx.id);
          return { ...tx, status: ['Pending', 'Approved', 'Delayed', 'Rejected'][status] };
        })
      );
      setTransactions(updatedTransactions);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="w-full max-w-4xl mx-auto p-4 space-y-4">
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center justify-between">
            <span>AI_Sec_Lotus Interface</span>
            {account ? (
              <span className="text-sm text-green-600">
                Connected: {account.slice(0, 6)}...{account.slice(-4)}
              </span>
            ) : (
              <Button 
                onClick={connectWallet} 
                disabled={loading}
                className="flex items-center gap-2"
              >
                <Wallet className="w-4 h-4" />
                Connect Wallet
              </Button>
            )}
          </CardTitle>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            {error && (
              <Alert variant="destructive">
                <AlertDescription>{error}</AlertDescription>
              </Alert>
            )}

            <div className="flex gap-2">
              <Input
                type="text"
                value={amount}
                onChange={(e) => setAmount(e.target.value)}
                placeholder="Amount in ETH"
                disabled={!account || loading}
              />
              <Button
                onClick={handleTransaction}
                disabled={!account || loading || !amount}
                className="flex items-center gap-2"
              >
                <Send className="w-4 h-4" />
                Send
              </Button>
            </div>

            <div className="space-y-2">
              <div className="flex items-center justify-between">
                <h3 className="text-lg font-semibold">Transactions</h3>
                <Button
                  variant="outline"
                  size="sm"
                  onClick={refreshTransactions}
                  disabled={loading || transactions.length === 0}
                  className="flex items-center gap-2"
                >
                  <RefreshCw className="w-4 h-4" />
                  Refresh
                </Button>
              </div>

              <div className="space-y-2">
                {transactions.map((tx) => (
                  <div
                    key={tx.id}
                    className="p-3 border rounded-lg flex items-center justify-between"
                  >
                    <div>
                      <p className="text-sm font-medium">
                        ID: {tx.id}
                      </p>
                      <p className="text-sm text-gray-500">
                        Amount: {tx.amount} ETH
                      </p>
                    </div>
                    <div className="flex items-center gap-2">
                      {tx.status === 'Pending' && (
                        <span className="text-yellow-600">⏳</span>
                      )}
                      {tx.status === 'Approved' && (
                        <span className="text-green-600">✓</span>
                      )}
                      {tx.status === 'Rejected' && (
                        <span className="text-red-600">✗</span>
                      )}
                      {tx.status === 'Delayed' && (
                        <ShieldAlert className="w-4 h-4 text-orange-500" />
                      )}
                      <span className={`text-sm font-medium ${
                        tx.status === 'Approved' ? 'text-green-600' :
                        tx.status === 'Rejected' ? 'text-red-600' :
                        tx.status === 'Delayed' ? 'text-orange-500' :
                        'text-yellow-600'
                      }`}>
                        {tx.status}
                      </span>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </CardContent>
      </Card>
    </div>
  );
};

export default Web3Interface;