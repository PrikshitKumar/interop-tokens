"use client";

import React, { useState, useEffect } from "react";
import { ethers } from "ethers";
import {
  ArrowLeftRight,
  BarChart3,
  Clock,
  Settings,
  Sun,
  Moon,
  AlertCircle,
  LogOut,
  Loader2,
} from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { abi } from "../artifacts/InteropToken.json";

const CONTRACT_ADDRESS = "0x5FbDB2315678afecb367f032d93F642f64180aa3";
const RPC_URL = "http://127.0.0.1:8545/";
const CHAIN_ID = 31337;

// Custom hook for persistent state
const usePersistedState = (key: string, defaultValue: any) => {
  const [state, setState] = useState(() => {
    // Only attempt to read from localStorage when running on the client-side
    if (typeof window !== "undefined") {
      const saved = localStorage.getItem(key);
      if (saved !== null) {
        return JSON.parse(saved);
      }
    }
    return defaultValue;
  });

  useEffect(() => {
    if (typeof window !== "undefined") {
      localStorage.setItem(key, JSON.stringify(state));
    }
  }, [key, state]);

  return [state, setState];
};

const DashboardPage = () => {
  // Persisted states
  const [isDarkMode, setIsDarkMode] = usePersistedState("darkMode", false);
  const [userAddress, setUserAddress] = usePersistedState("userAddress", "");
  const [transferForm, setTransferForm] = usePersistedState("transferForm", {
    recipient: "",
    amount: "",
  });
  const [openForm, setOpenForm] = usePersistedState("openForm", {
    toChain: 0,
    amount: "",
    recipient: "",
    feeToken: ethers.ZeroAddress,
    feeValue: "0",
  });
  const [fillOrderId, setFillOrderId] = usePersistedState("userAddress", "");

  // Blockchain states
  const [provider, setProvider] = useState<any>(null);
  const [signer, setSigner] = useState<any>(null);
  const [contract, setContract] = useState<any>(null);
  const [account, setAccount] = useState<string>("");
  const [balance, setBalance] = useState<string>("");
  const [pendingOrders, setPendingOrders] = useState<any[]>([]);
  const [stats, setStats] = useState({
    totalOrders: 0,
    pendingOrders: 0,
    completedOrders: 0,
    totalVolume: "0 TST",
  });

  // UI states
  const [isWalletConnecting, setIsWalletConnecting] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Initialize Web3 and check for existing connection
  useEffect(() => {
    initializeWeb3();
    checkExistingConnection();
    return () => {
      // Cleanup event listeners
      if (contract) {
        contract.removeAllListeners();
      }
    };
  }, []);

  // Auto-refresh data
  useEffect(() => {
    if (contract) {
      const refreshInterval = setInterval(() => {
        refreshData();
      }, 30000); // Refresh every 30 seconds

      return () => clearInterval(refreshInterval);
    }
  }, [contract, account]);

  // Wallet event listeners
  useEffect(() => {
    if (typeof window !== "undefined" && (window as any).ethereum) {
      const handleAccountsChanged = (accounts: string[]) => {
        if (accounts.length > 0) {
          handleWalletConnection(accounts[0]);
        } else {
          disconnectWallet();
        }
      };

      const handleChainChanged = () => {
        window.location.reload();
      };

      (window as any).ethereum.on("accountsChanged", handleAccountsChanged);
      (window as any).ethereum.on("chainChanged", handleChainChanged);

      return () => {
        (window as any).ethereum.removeListener(
          "accountsChanged",
          handleAccountsChanged
        );
        (window as any).ethereum.removeListener(
          "chainChanged",
          handleChainChanged
        );
      };
    }
  }, []);

  const initializeWeb3 = async () => {
    try {
      setIsLoading(true);
      const web3Provider = new ethers.JsonRpcProvider(RPC_URL);
      setProvider(web3Provider);

      const contractInstance = new ethers.Contract(
        CONTRACT_ADDRESS,
        abi,
        web3Provider
      );
      setContract(contractInstance);
      // Set up event listeners
      setupEventListeners(contractInstance);
    } catch (error) {
      console.error("Failed to initialize Web3:", error);
      setError("Failed to initialize Web3 connection");
    } finally {
      setIsLoading(false);
    }
  };

  const checkExistingConnection = async () => {
    if (typeof window === "undefined" || !(window as any).ethereum) return;

    try {
      const accounts = await (window as any).ethereum.request({
        method: "eth_accounts",
      });

      if (accounts.length > 0) {
        await handleWalletConnection(accounts[0]);
      }
    } catch (error) {
      console.error("Error checking existing connection:", error);
    }
  };

  const refreshData = async () => {
    if (!contract) return;

    try {
      await Promise.all([
        fetchPendingOrders(),
        updateStats(),
        account && fetchBalance(),
      ]);
    } catch (error) {
      console.error("Error refreshing data:", error);
    }
  };

  const setupEventListeners = (contractInstance: ethers.Contract) => {
    contractInstance.removeAllListeners();

    const eventHandlers = {
      Open: async (standardizedOrderId: any, resolvedOrder: any) => {
        await refreshData();
      },
      Fill: async (orderId: any) => {
        await refreshData();
      },
      Confirm: async (orderId: any) => {
        await refreshData();
      },
      Cancel: async (orderId: any) => {
        await refreshData();
      },
    };

    Object.entries(eventHandlers).forEach(([event, handler]) => {
      contractInstance.on(event, handler);
    });
  };

  const handleWalletConnection = async (address: string) => {
    try {
      const web3Provider = new ethers.BrowserProvider((window as any).ethereum);
      const web3Signer = await web3Provider.getSigner();

      setSigner(web3Signer);
      setAccount(address);

      const contractWithSigner = new ethers.Contract(
        CONTRACT_ADDRESS,
        abi,
        web3Signer
      );
      setContract(contractWithSigner);

      await refreshData();
    } catch (error) {
      console.error("Failed to handle wallet connection:", error);
      setError("Failed to connect wallet");
    }
  };

  const connectWallet = async () => {
    if (isWalletConnecting) return;
    setIsWalletConnecting(true);
    setError(null);

    try {
      if (!(window as any).ethereum) {
        throw new Error("Please install MetaMask!");
      }

      const accounts = await (window as any).ethereum.request({
        method: "eth_requestAccounts",
      });

      if (accounts.length > 0) {
        await handleWalletConnection(accounts[0]);
      }
    } catch (error: any) {
      console.error("Failed to connect wallet:", error);
      setError(error.message || "Failed to connect wallet");
    } finally {
      setIsWalletConnecting(false);
    }
  };

  const disconnectWallet = () => {
    setSigner(null);
    setAccount("");
    setBalance("");
    setError(null);
  };

  const fetchBalance = async () => {
    if (!contract || !userAddress) return;

    try {
      if (!ethers.isAddress(userAddress)) {
        throw new Error("Invalid address");
      }

      const balance = await contract.balanceOf(userAddress);
      setBalance(ethers.formatEther(balance));
    } catch (error) {
      console.error("Failed to fetch balance:", error);
      return "0";
    }
  };

  const fetchPendingOrders = async () => {
    if (!contract) return;

    try {
      // Fetch the 'Open' events that were emitted
      const events = await contract.queryFilter("Open");

      // Use a Set to track unique orderIds and avoid duplicates
      const uniqueOrderIds = new Set();

      const orders = await Promise.all(
        events.map(
          async (event: { args: { resolvedOrder: { orderId: string } } }) => {
            const orderId = event.args.resolvedOrder.orderId;

            // Skip the order if it has already been processed
            if (uniqueOrderIds.has(orderId)) return null;

            uniqueOrderIds.add(orderId);

            try {
              // Fetch the order from the contract's state
              const order = await contract.pendingOrders(orderId);

              return {
                id: orderId,
                from: order.from,
                amount: ethers.formatEther(order.orderData.amount),
                status: "Pending", // You can change this if needed
              };
            } catch (error) {
              console.error(`Error fetching order with ID ${orderId}:`, error);
              return null;
            }
          }
        )
      );

      // Filter out any null orders that couldn't be fetched
      const validOrders = orders.filter((order) => order !== null);

      console.log("orders: ", validOrders);
      setPendingOrders(validOrders);
    } catch (error) {
      console.error("Failed to fetch pending orders:", error);
    }
  };

  const updateStats = async () => {
    if (!contract) return;

    try {
      const events = await contract.queryFilter("Open");
      const fillEvents = await contract.queryFilter("Fill");

      setStats({
        totalOrders: events.length,
        pendingOrders: events.length - fillEvents.length,
        completedOrders: fillEvents.length,
        totalVolume: `${events.reduce(
          (acc: number, event: any) =>
            acc +
            parseFloat(
              ethers.formatEther(event.args.resolvedOrder.maxSpent[0].amount)
            ),
          0
        )} TST`,
      });
    } catch (error) {
      console.error("Failed to update stats:", error);
    }
  };

  const handleTransfer = async () => {
    if (!contract || !signer) {
      setError("Please connect your wallet first");
      return;
    }

    try {
      setIsLoading(true);
      setError(null);

      const transfer = {
        to: transferForm.recipient,
        amount: ethers.parseEther(transferForm.amount),
      };

      const tx = await contract.transfer(transfer.to, transfer.amount);
      await tx.wait();

      // Reset form and refresh data
      setTransferForm({ recipient: "", amount: "" });
      await refreshData();
    } catch (error: any) {
      console.error("Transfer failed:", error);
      setError(error.message || "Transfer failed");
    } finally {
      setIsLoading(false);
    }
  };

  const handleOpen = async () => {
    if (!contract || !signer) {
      setError("Please connect your wallet first");
      return;
    }

    try {
      setIsLoading(true);
      setError(null);

      const abiCoder = ethers.AbiCoder.defaultAbiCoder();
      const orderData = abiCoder.encode(
        ["address", "uint256", "uint64", "address", "uint256"],
        [
          openForm.recipient,
          ethers.parseEther(openForm.amount),
          BigInt(openForm.toChain),
          openForm.feeToken,
          ethers.parseEther(openForm.feeValue),
        ]
      );

      const orderDataType = ethers.keccak256(
        ethers.solidityPacked(
          ["string"],
          ["Order(address,uint256,uint64,address,uint256)"]
        )
      );

      const order = {
        orderDataType: orderDataType,
        fillDeadline: Math.floor(Date.now() / 1000) + 3600,
        orderData: orderData,
      };

      const tx = await contract.open(order);
      await tx.wait();

      // Reset form and refresh data
      setOpenForm({
        toChain: 0,
        amount: "",
        recipient: "",
        feeToken: ethers.ZeroAddress,
        feeValue: "0",
      });

      await refreshData();
    } catch (error: any) {
      console.error("Order submission failed:", error);
      setError(error.message || "Order submission failed");
    } finally {
      setIsLoading(false);
    }
  };

  const handleFillOrder = async () => {
    if (!contract || !signer) {
      setError("Please connect your wallet first");
      return;
    }

    try {
      setIsLoading(true);
      setError(null);

      // Fetch the 'Open' events to extract order details
      const events = await contract.queryFilter("Open");
      let fillInstructions;
      let orderId;

      for (const event of events) {
        if (event.args.resolvedOrder.orderId === fillOrderId) {
          orderId = event.args.resolvedOrder.orderId;
          fillInstructions = event.args.resolvedOrder.fillInstructions;
          break;
        }
      }

      if (!orderId || !fillInstructions || fillInstructions.length === 0) {
        setError("No valid Fill Instructions found for this order.");
        return;
      }

      // Loop through the fillInstructions and execute fill
      for (const instruction of fillInstructions) {
        const tx = await contract.fill(orderId, instruction.originData, "0x");
        await tx.wait();
      }

      // Reset form and refresh data
      setFillOrderId(0);
      await refreshData();
    } catch (error: any) {
      console.error("Filling Order failed:", error);
      setError(error.message || "Filling Order failed");
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div
      className={`min-h-screen transition-colors duration-200 ${
        isDarkMode ? "dark bg-gray-900 text-white" : "bg-gray-50"
      }`}
    >
      {/* Header */}
      <header className="sticky top-0 z-10 border-b p-4 backdrop-blur-sm bg-opacity-90 bg-white dark:bg-gray-900 dark:bg-opacity-90">
        <div className="container mx-auto flex justify-between items-center">
          <h1 className="text-2xl font-bold">InteropToken Bridge</h1>
          <div className="flex items-center gap-4">
            <button
              onClick={() => setIsDarkMode(!isDarkMode)}
              className="p-2 rounded-full hover:bg-gray-200 dark:hover:bg-gray-700 transition-colors"
              aria-label={
                isDarkMode ? "Switch to light mode" : "Switch to dark mode"
              }
            >
              {isDarkMode ? <Sun size={20} /> : <Moon size={20} />}
            </button>

            {account ? (
              <div className="flex items-center gap-2">
                <span className="text-sm">
                  {`${account.slice(0, 6)}...${account.slice(-4)}`}
                </span>
                <button
                  onClick={disconnectWallet}
                  className="flex items-center gap-2 px-4 py-2 rounded-lg bg-red-600 text-white hover:bg-red-700 transition-colors"
                >
                  <LogOut size={16} />
                  Disconnect
                </button>
              </div>
            ) : (
              <button
                onClick={connectWallet}
                disabled={isWalletConnecting}
                className="flex items-center gap-2 px-4 py-2 rounded-lg bg-blue-600 text-white hover:bg-blue-700 transition-colors disabled:opacity-50"
              >
                {isWalletConnecting ? (
                  <>
                    <Loader2 className="animate-spin" size={16} />
                    Connecting...
                  </>
                ) : (
                  "Connect Wallet"
                )}
              </button>
            )}
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="container mx-auto p-4 space-y-8">
        {/* Error Alert */}
        {error && (
          <Alert variant="destructive">
            <AlertCircle className="h-4 w-4" />
            <AlertDescription>{error}</AlertDescription>
          </Alert>
        )}

        {/* Stats Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
          <Card className="transition-all duration-200 hover:shadow-lg">
            <CardHeader className="flex flex-row items-center justify-between pb-2">
              <CardTitle className="text-sm font-medium">
                Total Orders
              </CardTitle>
              <BarChart3 className="h-4 w-4 text-gray-500" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">{stats.totalOrders}</div>
            </CardContent>
          </Card>

          <Card className="transition-all duration-200 hover:shadow-lg">
            <CardHeader className="flex flex-row items-center justify-between pb-2">
              <CardTitle className="text-sm font-medium">
                Pending Orders
              </CardTitle>
              <Clock className="h-4 w-4 text-gray-500" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">{stats.pendingOrders}</div>
            </CardContent>
          </Card>

          <Card className="transition-all duration-200 hover:shadow-lg">
            <CardHeader className="flex flex-row items-center justify-between pb-2">
              <CardTitle className="text-sm font-medium">
                Completed Orders
              </CardTitle>
              <ArrowLeftRight className="h-4 w-4 text-gray-500" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">{stats.completedOrders}</div>
            </CardContent>
          </Card>

          <Card className="transition-all duration-200 hover:shadow-lg">
            <CardHeader className="flex flex-row items-center justify-between pb-2">
              <CardTitle className="text-sm font-medium">
                Total Volume
              </CardTitle>
              <Settings className="h-4 w-4 text-gray-500" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">{stats.totalVolume}</div>
            </CardContent>
          </Card>
        </div>

        {/* Fetch ERC-20 Balance */}
        <Card className="transition-all duration-200">
          <CardHeader>
            <CardTitle>Check Token Balance</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div className="space-y-4">
                <label className="block">
                  <span className="text-sm font-medium">User Address</span>
                  <input
                    type="text"
                    className="mt-1 block w-full rounded-md border border-gray-300 bg-white py-2 px-3 shadow-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500 dark:bg-gray-800 dark:border-gray-600 dark:text-white transition-colors"
                    placeholder="Enter user address"
                    value={userAddress}
                    onChange={(e) => setUserAddress(e.target.value)}
                  />
                </label>

                <button
                  onClick={fetchBalance}
                  disabled={isLoading}
                  className="w-full py-2 px-4 rounded-lg bg-blue-600 text-white hover:bg-blue-700 transition-colors disabled:opacity-50 flex items-center justify-center gap-2"
                >
                  {isLoading ? (
                    <>
                      <Loader2 className="animate-spin" size={16} />
                      Checking Balance...
                    </>
                  ) : (
                    "Check Balance"
                  )}
                </button>

                {balance && (
                  <div className="mt-4 p-4 rounded-lg bg-gray-100 dark:bg-gray-800 transition-colors">
                    <p className="text-lg font-semibold">
                      Balance: {balance} TST
                    </p>
                  </div>
                )}
              </div>
            </div>
          </CardContent>
        </Card>

        {/* Transfer ERC-20 Section */}
        <Card className="transition-all duration-200">
          <CardHeader>
            <CardTitle>Transfer Tokens</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div className="space-y-4">
                <label className="block">
                  <span className="text-sm font-medium">Amount</span>
                  <input
                    type="text"
                    className="mt-1 block w-full rounded-md border border-gray-300 bg-white py-2 px-3 shadow-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500 dark:bg-gray-800 dark:border-gray-600 dark:text-white transition-colors"
                    placeholder="Enter amount"
                    value={transferForm.amount}
                    onChange={(e) =>
                      setTransferForm({
                        ...transferForm,
                        amount: e.target.value,
                      })
                    }
                  />
                </label>
                <label className="block">
                  <span className="text-sm font-medium">Recipient Address</span>
                  <input
                    type="text"
                    className="mt-1 block w-full rounded-md border border-gray-300 bg-white py-2 px-3 shadow-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500 dark:bg-gray-800 dark:border-gray-600 dark:text-white transition-colors"
                    placeholder="Enter recipient address"
                    value={transferForm.recipient}
                    onChange={(e) =>
                      setTransferForm({
                        ...transferForm,
                        recipient: e.target.value,
                      })
                    }
                  />
                </label>

                <button
                  onClick={handleTransfer}
                  disabled={isLoading || !account}
                  className="w-full py-2 px-4 rounded-lg bg-blue-600 text-white hover:bg-blue-700 transition-colors disabled:opacity-50 flex items-center justify-center gap-2"
                >
                  {isLoading ? (
                    <>
                      <Loader2 className="animate-spin" size={16} />
                      Processing Transfer...
                    </>
                  ) : (
                    "Transfer Tokens"
                  )}
                </button>
              </div>
            </div>
          </CardContent>
        </Card>

        {/* Cross-Chain Transfer Section */}
        <Card className="transition-all duration-200">
          <CardHeader>
            <CardTitle>Cross-Chain Transfer</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div className="space-y-4">
                <label className="block">
                  <span className="text-sm font-medium">Amount</span>
                  <input
                    type="text"
                    className="mt-1 block w-full rounded-md border border-gray-300 bg-white py-2 px-3 shadow-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500 dark:bg-gray-800 dark:border-gray-600 dark:text-white transition-colors"
                    placeholder="Enter amount"
                    value={openForm.amount}
                    onChange={(e) =>
                      setOpenForm({
                        ...openForm,
                        amount: e.target.value,
                      })
                    }
                  />
                </label>

                <label className="block">
                  <span className="text-sm font-medium">To Chain ID</span>
                  <input
                    type="number"
                    className="mt-1 block w-full rounded-md border border-gray-300 bg-white py-2 px-3 shadow-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500 dark:bg-gray-800 dark:border-gray-600 dark:text-white transition-colors"
                    placeholder="Enter destination chain ID"
                    value={openForm.toChain}
                    onChange={(e) =>
                      setOpenForm({
                        ...openForm,
                        toChain: parseInt(e.target.value) || 0,
                      })
                    }
                  />
                </label>

                <label className="block">
                  <span className="text-sm font-medium">Recipient Address</span>
                  <input
                    type="text"
                    className="mt-1 block w-full rounded-md border border-gray-300 bg-white py-2 px-3 shadow-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500 dark:bg-gray-800 dark:border-gray-600 dark:text-white transition-colors"
                    placeholder="Enter recipient address"
                    value={openForm.recipient}
                    onChange={(e) =>
                      setOpenForm({
                        ...openForm,
                        recipient: e.target.value,
                      })
                    }
                  />
                </label>
              </div>
            </div>

            <button
              onClick={handleOpen}
              disabled={isLoading || !account}
              className="mt-6 w-full py-2 px-4 rounded-lg bg-blue-600 text-white hover:bg-blue-700 transition-colors disabled:opacity-50 flex items-center justify-center gap-2"
            >
              {isLoading ? (
                <>
                  <Loader2 className="animate-spin" size={16} />
                  Processing Order...
                </>
              ) : (
                "Submit Order"
              )}
            </button>
          </CardContent>
        </Card>

        {/* Fill Order Section */}
        <Card className="transition-all duration-200">
          <CardHeader>
            <CardTitle>Fill Order</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div className="space-y-4">
                <label className="block">
                  <span className="text-sm font-medium">OrderId</span>
                  <input
                    type="text"
                    className="mt-1 block w-full rounded-md border border-gray-300 bg-white py-2 px-3 shadow-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500 dark:bg-gray-800 dark:border-gray-600 dark:text-white transition-colors"
                    placeholder="Enter Order ID"
                    value={fillOrderId}
                    onChange={(e) => setFillOrderId(e.target.value)}
                  />
                </label>
              </div>
            </div>

            <button
              onClick={handleFillOrder}
              disabled={isLoading || !account}
              className="mt-6 w-full py-2 px-4 rounded-lg bg-blue-600 text-white hover:bg-blue-700 transition-colors disabled:opacity-50 flex items-center justify-center gap-2"
            >
              {isLoading ? (
                <>
                  <Loader2 className="animate-spin" size={16} />
                  Processing Order...
                </>
              ) : (
                "Execute Order"
              )}
            </button>
          </CardContent>
        </Card>

        {/* Pending Orders Section */}
        <Card className="transition-all duration-200">
          <CardHeader>
            <CardTitle>Pending Orders</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="overflow-x-auto">
              {pendingOrders.length > 0 ? (
                <table className="w-full">
                  <thead>
                    <tr className="border-b dark:border-gray-700">
                      <th className="text-left py-3 px-4">Order ID</th>
                      <th className="text-left py-3 px-4">From</th>
                      <th className="text-left py-3 px-4">Amount</th>
                      <th className="text-left py-3 px-4">Status</th>
                    </tr>
                  </thead>
                  <tbody>
                    {pendingOrders.map((order: any) => (
                      <tr
                        key={order.id}
                        className="border-b dark:border-gray-700 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors"
                      >
                        <td className="py-3 px-4">{order.id}</td>
                        <td className="py-3 px-4">
                          {`${order.from.slice(0, 6)}...${order.from.slice(
                            -4
                          )}`}
                        </td>
                        <td className="py-3 px-4">{order.amount} TST</td>
                        <td className="py-3 px-4">
                          <span
                            className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${
                              order.status === "Pending"
                                ? "bg-yellow-100 text-yellow-800"
                                : "bg-blue-100 text-blue-800"
                            }`}
                          >
                            {order.status}
                          </span>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              ) : (
                <div className="text-center py-8 text-gray-500 dark:text-gray-400">
                  No pending orders found
                </div>
              )}
            </div>
          </CardContent>
        </Card>

        {/* Network Status */}
        <Alert>
          <AlertCircle className="h-4 w-4" />
          <AlertDescription>
            Connected to Local Network (Chain ID: {CHAIN_ID})
          </AlertDescription>
        </Alert>
      </main>
    </div>
  );
};

export default DashboardPage;
