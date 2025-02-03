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
} from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { abi } from "../artifacts/InteropToken.json";

const CONTRACT_ADDRESS = "0x5FbDB2315678afecb367f032d93F642f64180aa3";
const RPC_URL = "http://127.0.0.1:8545/";
const CHAIN_ID = 31337;

const DashboardPage = () => {
  const [isDarkMode, setIsDarkMode] = useState(false);
  const [provider, setProvider] = useState<any>(null);
  const [signer, setSigner] = useState<any>(null);
  const [contract, setContract] = useState<any>(null);
  const [account, setAccount] = useState<any>("");
  const [userAddress, setUserAddress] = useState<any>(""); // State for input address
  const [balance, setBalance] = useState<any>("");
  const [pendingOrders, setPendingOrders] = useState<any>([]);
  const [stats, setStats] = useState<any>({
    totalOrders: 0,
    pendingOrders: 0,
    completedOrders: 0,
    totalVolume: "0 ITKN",
  });
  // Form state
  const [transferForm, setTransferForm] = useState({
    recipient: "",
    amount: "",
  });
  const [openForm, setOpenForm] = useState({
    toChain: 0,
    amount: "",
    recipient: "",
    feeToken: ethers.ZeroAddress,
    feeValue: "0",
  });
  useEffect(() => {
    initializeWeb3();
  }, []);
  const initializeWeb3 = async () => {
    try {
      // Connect to provider
      const web3Provider = new ethers.JsonRpcProvider(RPC_URL);
      setProvider(web3Provider);
      // Create contract instance
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
    }
  };
  const connectWallet = async () => {
    try {
      if ((window as any).ethereum) {
        await (window as any).ethereum.request({
          method: "eth_requestAccounts",
        });
        const web3Provider = new ethers.BrowserProvider(
          (window as any).ethereum
        );

        const web3Signer = await web3Provider.getSigner();
        const address = await web3Signer.getAddress();

        console.log("Address: ", address);

        setSigner(web3Signer);
        setAccount(address);

        // Create contract instance with signer
        const contractWithSigner = new ethers.Contract(
          CONTRACT_ADDRESS,
          abi,
          web3Signer
        );
        setContract(contractWithSigner);
      }
    } catch (error) {
      console.error("Failed to connect wallet:", error);
    }
  };
  const setupEventListeners = (contractInstance: ethers.Contract) => {
    contractInstance.removeAllListeners(); // Remove previous listeners to avoid duplication

    contractInstance.on(
      "Open",
      (standardizedOrderId: any, resolvedOrder: any) => {
        fetchPendingOrders();
        updateStats();
      }
    );
    contractInstance.on("Fill", (orderId: any) => {
      fetchPendingOrders();
      updateStats();
    });
    contractInstance.on("Confirm", (orderId: any) => {
      fetchPendingOrders();
      updateStats();
    });
    contractInstance.on("Cancel", (orderId: any) => {
      fetchPendingOrders();
      updateStats();
    });
  };
  const fetchPendingOrders = async () => {
    try {
      // This is a simplified version - you'll need to implement your own logic
      // to track and fetch pending orders, possibly using events or your own indexing
      const events = await contract.queryFilter("Open");
      const orders = await Promise.all(
        events.map(async (event: { args: { standardizedOrderId: any } }) => {
          const order = await contract.pendingOrders(
            event.args.standardizedOrderId
          );
          return {
            id: event.args.standardizedOrderId,
            from: order.from,
            amount: ethers.formatEther(order.orderData.amount),
            status: "Pending",
          };
        })
      );
      setPendingOrders(orders);
    } catch (error) {
      console.error("Failed to fetch pending orders:", error);
    }
  };
  const updateStats = async () => {
    try {
      const events = await contract.queryFilter("Open");
      const fillEvents = await contract.queryFilter("Fill");

      setStats({
        totalOrders: events.length,
        pendingOrders: events.length - fillEvents.length,
        completedOrders: fillEvents.length,
        totalVolume: `${events.reduce(
          (
            acc: number,
            event: {
              args: {
                resolvedOrder: { maxSpent: { amount: ethers.BigNumberish }[] };
              };
            }
          ) =>
            acc +
            parseFloat(
              ethers.formatEther(event.args.resolvedOrder.maxSpent[0].amount)
            ),
          0
        )} ITKN`,
      });
    } catch (error) {
      console.error("Failed to update stats:", error);
    }
  };
  const fetchBalance = async () => {
    try {
      if (!contract) {
        console.warn("Contract is not initialized yet.");
        return;
      }

      if (!ethers.isAddress(userAddress)) {
        alert("Invalid address!");
        return;
      }

      const balance = await contract.balanceOf(userAddress);
      setBalance(ethers.formatEther(balance)); // Convert from Wei and update UI
    } catch (error) {
      console.error("Failed to fetch balance:", error);
      return "0";
    }
  };
  const handleTransfer = async () => {
    try {
      if (!contract || !signer) {
        alert("Please connect your wallet first");
        return;
      }

      // 1. Prepare the transaction
      const transfer = {
        to: transferForm.recipient,
        amount: ethers.parseEther(transferForm.amount), // Convert to Wei
      };

      const tx = await contract.transfer(transfer.to, transfer.amount);
      await tx.wait();

      /*
      // 2. Get the unsigned transaction
      const unsignedTx = await contract.transfer.populateTransaction(
        transfer.to,
        transfer.amount
      );

      // 3. Estimate gas
      const gasEstimate = await contract.transfer.estimateGas(
        transfer.to,
        transfer.amount
      );

      // 4. Add gas estimate to transaction
      unsignedTx.gasLimit = gasEstimate;

      // 5. Sign the transaction
      const signedTx = await signer.signTransaction(unsignedTx);

      // 6. Submit the transaction
      const tx = await signer.sendTransaction(signedTx);
      console.log("Transaction sent:", tx.hash);

      // 7. Wait for confirmation
      const receipt = await tx.wait();
      console.log("Transaction confirmed:", receipt);
      */
    } catch (error) {
      console.error("Transfer failed:", error);
      alert("Transfer failed. See console for details.");
    }
  };
  const handleOpen = async () => {
    try {
      if (!contract || !signer) {
        alert("Please connect your wallet first");
        return;
      }

      const abiCoder = ethers.AbiCoder.defaultAbiCoder();

      // Match Solidity's struct encoding
      const orderData = abiCoder.encode(
        ["address", "uint256", "uint64", "address", "uint256"],
        [
          openForm.recipient,
          ethers.parseEther(openForm.amount), // Convert to Wei
          BigInt(openForm.toChain), // Ensure proper type
          openForm.feeToken,
          ethers.parseEther(openForm.feeValue), // Convert to Wei
        ]
      );

      // Use correct hashing (ensure it matches Solidity)
      // const orderDataType = ethers.keccak256(
      //   ethers.toUtf8Bytes("OrderData(address,uint256,uint64,address,uint256)")
      // );
      const orderDataType = ethers.keccak256(
        ethers.solidityPacked(["string"], ["Order(address,uint256,uint64,address,uint256)"])
      );

      // Construct order
      const order = {
        orderDataType: orderDataType,
        fillDeadline: Math.floor(Date.now() / 1000) + 3600, // 1 hour from now
        orderData: orderData,
      };

      // Send transaction
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

      fetchPendingOrders();
      updateStats();
    } catch (error) {
      console.error("Transfer failed:", error);
      alert("Transfer failed. See console for details.");
    }
  };

  return (
    <div
      className={`min-h-screen ${
        isDarkMode ? "dark bg-gray-900 text-white" : "bg-gray-50"
      }`}
    >
      {/* Header */}
      <header className="border-b p-4">
        <div className="container mx-auto flex justify-between items-center">
          <h1 className="text-2xl font-bold">InteropToken Bridge</h1>
          <div className="flex items-center gap-4">
            <button
              onClick={() => setIsDarkMode(!isDarkMode)}
              className="p-2 rounded-full hover:bg-gray-200 dark:hover:bg-gray-700"
            >
              {isDarkMode ? <Sun size={20} /> : <Moon size={20} />}
            </button>
            <button
              onClick={connectWallet}
              className="flex items-center gap-2 px-4 py-2 rounded-lg bg-blue-600 text-white hover:bg-blue-700"
            >
              {account
                ? `Connected: ${account.slice(0, 6)}...${account.slice(-4)}`
                : "Connect Wallet"}
            </button>
          </div>
        </div>
      </header>
      {/* Main Content */}
      <main className="container mx-auto p-4">
        {/* Stats Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
          <Card>
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

          {/* ... Other stat cards ... */}
        </div>

        {/* Fetch ERC-20 Balance */}
        <Card className="mb-8">
          <CardHeader>
            <CardTitle>Fetch ERC-20 Tokens Balance</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div className="space-y-4">
                <label className="block">
                  <span className="text-sm font-medium">User Address</span>
                  <input
                    type="text"
                    className="mt-1 block w-full rounded-md border border-gray-300 bg-white py-2 px-3 shadow-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500 dark:bg-gray-800 dark:border-gray-600"
                    placeholder="Enter user address"
                    value={userAddress}
                    onChange={(e) => setUserAddress(e.target.value)}
                  />
                </label>

                {/* Fetch Balance Button */}
                <div className="mt-6">
                  <button
                    onClick={fetchBalance}
                    className="w-full py-2 px-4 rounded-lg bg-blue-600 text-white hover:bg-blue-700"
                  >
                    Check Balance
                  </button>
                </div>

                {/* Display Balance */}
                {balance && (
                  <p className="mt-2 text-gray-700 dark:text-gray-300">
                    Balance: {balance} ETH
                  </p>
                )}
              </div>
            </div>
          </CardContent>
        </Card>

        {/* Transfer ERC-20 Section */}
        <Card className="mb-8">
          <CardHeader>
            <CardTitle>Transfer ERC-20 Tokens</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div className="space-y-4">
                <label className="block">
                  <span className="text-sm font-medium">Amount</span>
                  <input
                    type="text"
                    className="mt-1 block w-full rounded-md border border-gray-300 bg-white py-2 px-3 shadow-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500 dark:bg-gray-800 dark:border-gray-600"
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
                    className="mt-1 block w-full rounded-md border border-gray-300 bg-white py-2 px-3 shadow-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500 dark:bg-gray-800 dark:border-gray-600"
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
              </div>
            </div>

            <div className="mt-6">
              <button
                onClick={handleTransfer}
                className="w-full py-2 px-4 rounded-lg bg-blue-600 text-white hover:bg-blue-700"
              >
                Transfer Tokens
              </button>
            </div>
          </CardContent>
        </Card>
        {/* Order Submission Section */}
        <Card className="mb-8">
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
                    className="mt-1 block w-full rounded-md border border-gray-300 bg-white py-2 px-3 shadow-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500 dark:bg-gray-800 dark:border-gray-600"
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
              </div>

              <div className="space-y-4">
                <label className="block">
                  <span className="text-sm font-medium">To Chain ID</span>
                  <input
                    type="text"
                    className="mt-1 block w-full rounded-md border border-gray-300 bg-white py-2 px-3 shadow-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500 dark:bg-gray-800 dark:border-gray-600"
                    placeholder="Enter destination chain ID"
                    value={openForm.toChain}
                    onChange={(e) =>
                      setOpenForm({
                        ...openForm,
                        toChain: parseInt(e.target.value),
                      })
                    }
                  />
                </label>

                <label className="block">
                  <span className="text-sm font-medium">Recipient Address</span>
                  <input
                    type="text"
                    className="mt-1 block w-full rounded-md border border-gray-300 bg-white py-2 px-3 shadow-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500 dark:bg-gray-800 dark:border-gray-600"
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

            <div className="mt-6">
              <button
                onClick={handleOpen}
                className="w-full py-2 px-4 rounded-lg bg-blue-600 text-white hover:bg-blue-700"
              >
                Submit Order
              </button>
            </div>
          </CardContent>
        </Card>
        {/* Pending Orders Section */}
        <Card>
          <CardHeader>
            <CardTitle>Pending Orders</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="overflow-x-auto">
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
                      className="border-b dark:border-gray-700"
                    >
                      <td className="py-3 px-4">{order.id}</td>
                      <td className="py-3 px-4">{order.from}</td>
                      <td className="py-3 px-4">{order.amount} ITKN</td>
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
            </div>
          </CardContent>
        </Card>
        {/* Network Status */}
        <div className="mt-8">
          <Alert>
            <AlertCircle className="h-4 w-4" />
            <AlertDescription>
              Connected to Local Network (Chain ID: {CHAIN_ID})
            </AlertDescription>
          </Alert>
        </div>
      </main>
    </div>
  );
};
export default DashboardPage;
