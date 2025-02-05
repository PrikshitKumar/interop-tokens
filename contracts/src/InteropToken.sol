// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;


import {IInteropToken} from "./interface/IInteropToken.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "./TokenStorage.sol";

import {OnchainCrossChainOrder, ResolvedCrossChainOrder, Output, FillInstruction, IOriginSettler, IDestinationSettler} from "./interface/IERC7683.sol";

contract InteropToken is
    IInteropToken,
    OwnableUpgradeable,
    TokenStorage,
    ReentrancyGuard
{
    error WrongOrderType();
    error OrderNotPending(bytes32 orderId);
    error UnauthorizedFiller(address sender, address filler);

    event Fill(bytes32 indexed orderId);
    event Confirm(bytes32 indexed orderId);
    event Cancel(bytes32 indexed orderId);


    /// modifiers

    /// @dev Modifier to make a function callable only when the contract is not paused.
    modifier whenNotPaused() {
        require(!_tokenPaused, "Pausable: paused");
        _;
    }

    /// @dev Modifier to make a function callable only when the contract is paused.
    modifier whenPaused() {
        require(_tokenPaused, "Pausable: not paused");
        _;
    }


    /**
     * @notice Restricts access to only the authorized filler.
     * @dev This modifier ensures that only the designated filler can execute the function it is applied to.
     *
     * Error:
     * - `UnauthorizedFiller`: Reverted if the caller is not the authorized filler.
     */
    modifier onlyFiller() {
        if (msg.sender != FILLER) revert UnauthorizedFiller(msg.sender, FILLER);
        _;
    }

    /**
     *  @dev this initiates the token contract
     *  msg.sender is set automatically as the owner of the smart contract
     *  @param _name the name of the token
     *  @param _symbol the symbol of the token
     *  @param _decimals the decimals of the token
     *  emits an `UpdatedTokenInformation` event
     */
    function init(
        address _initialOwner,
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) external initializer {
        // that require is protecting legacy versions of   contracts
        // as there was a bug with the initializer modifier on these proxies
        // that check is preventing attackers to call the init functions on those
        // legacy contracts.
        require(owner() == address(0), "already initialized");
        require(
            keccak256(abi.encode(_name)) != keccak256(abi.encode(""))
            && keccak256(abi.encode(_symbol)) != keccak256(abi.encode(""))
        , "invalid argument - empty string");
        require(0 <= _decimals && _decimals <= 18, "decimals between 0 and 18");
        __Ownable_init(_initialOwner);
        _tokenName = _name;
        _tokenSymbol = _symbol;
        _tokenDecimals = _decimals;

        emit UpdatedTokenInformation(_tokenName, _tokenSymbol, _tokenDecimals, _TOKEN_VERSION);
    }

    /**
     *  @dev See {IERC20-approve}.
     */
    function approve(address _spender, uint256 _amount) external virtual override returns (bool) {
        _approve(msg.sender, _spender, _amount);
        return true;
    }

    /**
     *  @dev See {ERC20-increaseAllowance}.
     */
    function increaseAllowance(address _spender, uint256 _addedValue) external virtual returns (bool) {
        _approve(msg.sender, _spender, _allowances[msg.sender][_spender] + (_addedValue));
        return true;
    }

    /**
     *  @dev See {ERC20-decreaseAllowance}.
     */
    function decreaseAllowance(address _spender, uint256 _subtractedValue) external virtual returns (bool) {
        _approve(msg.sender, _spender, _allowances[msg.sender][_spender] - _subtractedValue);
        return true;
    }

    /**
     *  @dev See {IToken-setName}.
     */
    function setName(string calldata _name) external override onlyOwner {
        require(keccak256(abi.encode(_name)) != keccak256(abi.encode("")), "invalid argument - empty string");
        _tokenName = _name;
        emit UpdatedTokenInformation(_tokenName, _tokenSymbol, _tokenDecimals, _TOKEN_VERSION);
    }

    /**
     *  @dev See {IToken-setSymbol}.
     */
    function setSymbol(string calldata _symbol) external override onlyOwner {
        require(keccak256(abi.encode(_symbol)) != keccak256(abi.encode("")), "invalid argument - empty string");
        _tokenSymbol = _symbol;
        emit UpdatedTokenInformation(_tokenName, _tokenSymbol, _tokenDecimals, _TOKEN_VERSION);
    }

     /**
     *  @dev See {IToken-pause}.
     */
    function pause() external override onlyOwner whenNotPaused {
        _tokenPaused = true;
        emit Paused(msg.sender);
    }

    /**
     *  @dev See {IToken-unpause}.
     */
    function unpause() external override onlyOwner whenPaused {
        _tokenPaused = false;
        emit Unpaused(msg.sender);
    }

    /**
     *  @dev See {IToken-batchTransfer}.
     */
    function batchTransfer(address[] calldata _toList, uint256[] calldata _amounts) external override {
        for (uint256 i = 0; i < _toList.length; i++) {
            transfer(_toList[i], _amounts[i]);
        }
    }

    /**
     *  @notice ERC-20 overridden function that include logic to check for trade validity.
     *  Require that the from and to addresses are not frozen.
     *  Require that the value should not exceed available balance .
     *  Require that the to address is a verified address
     *  @param _from The address of the sender
     *  @param _to The address of the receiver
     *  @param _amount The number of tokens to transfer
     *  @return `true` if successful and revert if unsuccessful
     */
    function transferFrom(
        address _from,
        address _to,
        uint256 _amount
    ) external override whenNotPaused returns (bool) {
        require(_amount <= balanceOf(_from), "Insufficient Balance");
        _approve(_from, msg.sender, _allowances[_from][msg.sender] - (_amount));
        _transfer(_from, _to, _amount);
        return true;        
    }

    /**
     *  @dev See {IToken-batchMint}.
     */
    function batchMint(address[] calldata _toList, uint256[] calldata _amounts) external override {
        for (uint256 i = 0; i < _toList.length; i++) {
            mint(_toList[i], _amounts[i]);
        }
    }

    /**
     *  @dev See {IToken-batchBurn}.
     */
    function batchBurn(address[] calldata _userAddresses, uint256[] calldata _amounts) external override {
        for (uint256 i = 0; i < _userAddresses.length; i++) {
            burn(_userAddresses[i], _amounts[i]);
        }
    }

     /**
     *  @notice ERC-20 overridden function that include logic to check for trade validity.
     *  Require that the msg.sender and to addresses are not frozen.
     *  Require that the value should not exceed available balance .
     *  Require that the to address is a verified address
     *  @param _to The address of the receiver
     *  @param _amount The number of tokens to transfer
     *  @return `true` if successful and revert if unsuccessful
     */
    function transfer(address _to, uint256 _amount) public override whenNotPaused returns (bool) {
        require(_amount <= balanceOf(msg.sender), "Insufficient Balance");
        _transfer(msg.sender, _to, _amount);
        return true;
    }

    /**
     *  @dev See {IToken-mint}.
     */
    function mint(address _to, uint256 _amount) public override onlyOwner {
        _mint(_to, _amount);
    }

    /**
     *  @dev See {IToken-burn}.
     */
    function burn(address _userAddress, uint256 _amount) public override onlyOwner {
        require(balanceOf(_userAddress) >= _amount, "cannot burn more than balance");
        _burn(_userAddress, _amount);
    }


    /// @notice Opens a cross-chain order
    /// @dev To be called by the user
    /// @dev This method must emit the Open event
    /// @param order The OnchainCrossChainOrder definition
    function open(OnchainCrossChainOrder calldata order) external nonReentrant {
        OrderData memory orderData = decode7683OrderData(order.orderData);
        ResolvedCrossChainOrder memory resolvedOrder = this.resolve(order);

        require(
            pendingOrders[resolvedOrder.orderId].from == address(0),
            "Order already pending"
        );
        OpenOrder memory openOrder = OpenOrder({
            from: msg.sender,
            orderData: orderData
        });

        pendingOrders[resolvedOrder.orderId] = openOrder;

        // order amount is taken in custody of the contract
        // to be released in the event of order cancellation due to filler failure
        // to be burnt in the event of a successful cross-chain transfer
        _transfer(msg.sender, address(this), orderData.amount);
        // TODO: Transfer the RelayFee (Native Tokens) to Filler

        emit IOriginSettler.Open(
            keccak256(resolvedOrder.fillInstructions[0].originData),
            resolvedOrder
        );
    }

    function resolve(
        OnchainCrossChainOrder calldata order
    ) external view returns (ResolvedCrossChainOrder memory) {
        if (order.orderDataType != ORDER_DATA_TYPE_HASH) {
            revert WrongOrderType();
        }

        OrderData memory orderData = decode7683OrderData(order.orderData);

        Output[] memory _maxSpent = new Output[](1);
        Output[] memory _minReceived = new Output[](1);
        FillInstruction[] memory _fillInstructions = new FillInstruction[](1);

        _maxSpent[0] = Output({
            token: _toBytes32(orderData.feeToken),
            amount: orderData.feeValue,
            recipient: _toBytes32(orderData.to),
            chainId: orderData.destinationChainId
        });

        _minReceived[0] = Output({
            token: _toBytes32(address(this)),
            amount: orderData.amount, // This amount represents the minimum relayer fee compensated for facilitating the transaction to Filler
            recipient: _toBytes32(address(0)), // TODO : Add filler address here from the implementation authority contract
            chainId: block.chainid
        });

        _fillInstructions[0] = FillInstruction({
            destinationChainId: orderData.destinationChainId,
            destinationSettler: _toBytes32(address(this)), // Token address is assumed to be matching on the destination chain
            originData: order.orderData
        });

        return
            ResolvedCrossChainOrder({
                user: msg.sender,
                originChainId: block.chainid,
                openDeadline: type(uint32).max, // No deadline for origin orders
                fillDeadline: order.fillDeadline,
                orderId: _generateOrderId(), // Generate order ID as hash of order data
                maxSpent: _maxSpent,
                minReceived: _minReceived,
                fillInstructions: _fillInstructions
            });
    }

    function fill(
        bytes32 orderId,
        bytes calldata originData,
        bytes calldata fillerData
    ) external nonReentrant onlyFiller {
        if (pendingOrders[orderId].from == address(0)) {
            revert OrderNotPending(orderId);
        }

        // TODO: Validate the sender to be an authorized filler address on implementation authority
        OrderData memory orderData = decode7683OrderData(originData);
        _mint(orderData.to, orderData.amount);

        emit Fill(orderId);

        // TODO: To be Decided, what fillerData should contain
        // decode7683FillInstruction(fillerData);
        fillerData;
    }

    function confirm(bytes32 orderId) external nonReentrant onlyFiller {
        require(pendingOrders[orderId].from != address(0), "Order not found");
        delete pendingOrders[orderId];
        emit Confirm(orderId);
    }

    function cancel(bytes32 orderId) external nonReentrant onlyFiller {
        require(
            pendingOrders[orderId].orderData.amount != 0,
            "Order not found"
        );
        OpenOrder memory openOrder = pendingOrders[orderId];
        _transfer(address(this), openOrder.from, openOrder.orderData.amount);
        delete pendingOrders[orderId];
        emit Cancel(orderId);
    }

    function _generateOrderId() internal view returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    block.timestamp, // Current block timestamp
                    block.prevrandao, // Randomness beacon value in PoS
                    msg.sender, // Transaction sender
                    block.number // Current block Number
                )
            );
    }


    /**
     *  @dev See {ERC20-_transfer}.
     */
    function _transfer(
        address _from,
        address _to,
        uint256 _amount
    ) internal virtual {
        require(_from != address(0), "ERC20: transfer from the zero address");
        require(_to != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(_from, _to, _amount);

        _balances[_from] = _balances[_from] - _amount;
        _balances[_to] = _balances[_to] + _amount;
        emit Transfer(_from, _to, _amount);
    }

    /**
     *  @dev See {ERC20-_mint}.
     */
    function _mint(address _userAddress, uint256 _amount) internal virtual {
        require(_userAddress != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), _userAddress, _amount);

        _totalSupply = _totalSupply + _amount;
        _balances[_userAddress] = _balances[_userAddress] + _amount;
        emit Transfer(address(0), _userAddress, _amount);
    }

    /**
     *  @dev See {ERC20-_burn}.
     */
    function _burn(address _userAddress, uint256 _amount) internal virtual {
        require(_userAddress != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(_userAddress, address(0), _amount);

        _balances[_userAddress] = _balances[_userAddress] - _amount;
        _totalSupply = _totalSupply - _amount;
        emit Transfer(_userAddress, address(0), _amount);
    }

    function _approve(
        address _owner,
        address _spender,
        uint256 _amount
    ) internal virtual {
        require(_owner != address(0), "ERC20: approve from the zero address");
        require(_spender != address(0), "ERC20: approve to the zero address");

        _allowances[_owner][_spender] = _amount;
        emit Approval(_owner, _spender, _amount);
    }


    /**
     *  @dev See {ERC20-_beforeTokenTransfer}.
     */
    // solhint-disable-next-line no-empty-blocks
    function _beforeTokenTransfer(address _from, address _to, uint256 _amount) internal virtual {}

 /**
     *  @dev See {IERC20-totalSupply}.
     */
    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    /**
     *  @dev See {IERC20-allowance}.
     */
    function allowance(address _owner, address _spender) external view virtual override returns (uint256) {
        return _allowances[_owner][_spender];
    }

     /**
     *  @dev See {IInteropToken-paused}.
     */
    function paused() external view override returns (bool) {
        return _tokenPaused;
    }

       /**
     *  @dev See {IInteropToken-decimals}.
     */
    function decimals() external view override returns (uint8) {
        return _tokenDecimals;
    }

    /**
     *  @dev See {IInteropToken-name}.
     */
    function name() external view override returns (string memory) {
        return _tokenName;
    }

    /**
     *  @dev See {IInteropToken-symbol}.
     */
    function symbol() external view override returns (string memory) {
        return _tokenSymbol;
    }

    /**
     *  @dev See {IInteropToken-version}.
     */
    function version() external pure override returns (string memory) {
        return _TOKEN_VERSION;
    }


    /**
     *  @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address _userAddress) public view override returns (uint256) {
        return _balances[_userAddress];
    }

    function _toBytes32(address input) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(input)));
    }

    function decode7683OrderData(
        bytes memory orderData
    ) public pure returns (OrderData memory) {
        return abi.decode(orderData, (OrderData));
    }

    function decode7683FillInstruction(
        bytes memory fillInstruction
    ) public pure returns (FillInstruction memory) {
        return abi.decode(fillInstruction, (FillInstruction));
    }
}
