// SPDX-License-Identifier: MIT
pragma solidity >=0.8.18;

import "solmate/auth/Owned.sol";
import "solmate/tokens/ERC20.sol";
import "forge-std/console.sol";
import "./TurnstileRegisterEntry.sol";

abstract contract ReflectToken is Owned, TurnstileRegisterEntry {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Transfer(address indexed from, address indexed to, uint256 amount);

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 amount
    );

    /*//////////////////////////////////////////////////////////////
                            EIP-2612 STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 internal immutable INITIAL_CHAIN_ID;

    bytes32 internal immutable INITIAL_DOMAIN_SEPARATOR;

    mapping(address => uint256) public nonces;

    /*//////////////////////////////////////////////////////////////
                               REFLECT STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(address => uint256) internal _rOwned;
    mapping(address => uint256) internal _tOwned;
    mapping(address => mapping(address => uint256)) internal _allowances;

    mapping(address => bool) internal _isExcluded;
    address[] internal _excluded;

    string public name;
    string public symbol;
    uint8 public immutable decimals;

    uint16 internal immutable TRANSFER_FEE_BP;
    uint256 internal constant MAX = ~uint256(0);
    uint256 internal _tTotal;
    uint256 internal _rTotal;
    uint256 internal _tFeeTotal;

    bool public initialized;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address _owner,
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        uint16 totalTransferFee
    ) Owned(_owner) TurnstileRegisterEntry() {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        TRANSFER_FEE_BP = totalTransferFee;

        INITIAL_CHAIN_ID = block.chainid;
        INITIAL_DOMAIN_SEPARATOR = computeDomainSeparator();
    }

    /*//////////////////////////////////////////////////////////////
                               ERC20 LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice The current total supply of the token
    function totalSupply() public view virtual returns (uint256) {
        return _tTotal;
    }

    /**
     * @notice The balance of an account
     * @param account The address of the account
     */
    function balanceOf(address account) public view virtual returns (uint256) {
        if (_isExcluded[account]) return _tOwned[account];
        return tokenFromReflection(_rOwned[account]);
    }

    /**
     * @notice Transfers tokens from the sender's account to a recipient
     * @param recipient The account receiving the transfer
     * @param amount The amount of tokens to be transfered
     */
    function transfer(
        address recipient,
        uint256 amount
    ) public virtual returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    /**
     * @notice Allows an account to spend for another
     * @param owner The owner of the spending account
     * @param spender The account actually spending the tokens
     */
    function allowance(
        address owner,
        address spender
    ) public view virtual returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(
        address spender,
        uint256 amount
    ) public virtual returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, msg.sender, _allowances[sender][msg.sender] - amount);
        return true;
    }

    function increaseAllowance(
        address spender,
        uint256 addedValue
    ) public virtual returns (bool) {
        _approve(
            msg.sender,
            spender,
            _allowances[msg.sender][spender] + addedValue
        );
        return true;
    }

    function decreaseAllowance(
        address spender,
        uint256 subtractedValue
    ) public virtual returns (bool) {
        _approve(
            msg.sender,
            spender,
            _allowances[msg.sender][spender] - subtractedValue
        );
        return true;
    }

    /*//////////////////////////////////////////////////////////////
                             EIP-2612 LOGIC
    //////////////////////////////////////////////////////////////*/

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual {
        require(deadline >= block.timestamp, "PERMIT_DEADLINE_EXPIRED");

        // Unchecked because the only math done is incrementing
        // the owner's nonce which cannot realistically overflow.
        unchecked {
            address recoveredAddress = ecrecover(
                keccak256(
                    abi.encodePacked(
                        "\x19\x01",
                        DOMAIN_SEPARATOR(),
                        keccak256(
                            abi.encode(
                                keccak256(
                                    "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
                                ),
                                owner,
                                spender,
                                value,
                                nonces[owner]++,
                                deadline
                            )
                        )
                    )
                ),
                v,
                r,
                s
            );

            require(
                recoveredAddress != address(0) && recoveredAddress == owner,
                "INVALID_SIGNER"
            );

            _allowances[recoveredAddress][spender] = value;
        }

        emit Approval(owner, spender, value);
    }

    function DOMAIN_SEPARATOR() public view virtual returns (bytes32) {
        return
            block.chainid == INITIAL_CHAIN_ID
                ? INITIAL_DOMAIN_SEPARATOR
                : computeDomainSeparator();
    }

    function computeDomainSeparator() internal view virtual returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    keccak256(
                        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                    ),
                    keccak256(bytes(name)),
                    keccak256("1"),
                    block.chainid,
                    address(this)
                )
            );
    }

    /*//////////////////////////////////////////////////////////////
                             REFLECT LOGIC
    //////////////////////////////////////////////////////////////*/

    function mintInitialSupply(
        address recipient,
        uint256 amount
    ) public onlyOwner {
        require(!initialized, "Initialized");
        require(_isExcluded[recipient], "Recipient not excluded");

        initialized = true;
        _tTotal = amount;
        _rTotal = (MAX - (MAX % amount));
        _tOwned[recipient] = amount;
        _rOwned[recipient] = (MAX - (MAX % amount));

        emit Transfer(address(0), recipient, amount);
    }

    function totalFees() public view returns (uint256) {
        return _tFeeTotal;
    }

    function reflectionFromToken(
        uint256 tokenAmount,
        bool deductTransferFee
    ) public view returns (uint256) {
        require(tokenAmount <= _tTotal, "Amount must be less than supply");
        if (!deductTransferFee) {
            (uint256 reflectedAmount, , , , ) = _getValues(tokenAmount);
            return reflectedAmount;
        } else {
            (, uint256 tokenTransferAmount, , , ) = _getValues(tokenAmount);
            return tokenTransferAmount;
        }
    }

    function tokenFromReflection(
        uint256 reflectedAmount
    ) public view returns (uint256) {
        require(
            reflectedAmount <= _rTotal,
            "Amount must be less than total reflections"
        );
        uint256 currentRate = _getRate();
        return reflectedAmount / currentRate;
    }

    function isExcluded(address account) public view returns (bool) {
        return _isExcluded[account];
    }

    function excludeAccount(address account) external onlyOwner {
        require(!_isExcluded[account], "Account is already excluded");
        _excludeAccount(account);
    }

    function includeAccount(address account) external onlyOwner {
        require(_isExcluded[account], "Account is already included");
        _includeAccount(account);
    }

    function _excludeAccount(address account) internal {
        if (_rOwned[account] > 0) {
            _tOwned[account] = tokenFromReflection(_rOwned[account]);
        }
        _isExcluded[account] = true;
        _excluded.push(account);
    }

    function _includeAccount(address account) internal {
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_excluded[i] == account) {
                _excluded[i] = _excluded[_excluded.length - 1];
                _tOwned[account] = 0;
                _isExcluded[account] = false;
                _excluded.pop();
                break;
            }
        }
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "Reflect: approve 0addr");
        require(spender != address(0), "Reflect: approve 0addr");

        _allowances[owner][spender] = amount;

        emit Approval(owner, spender, amount);
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal {
        require(sender != address(0), "Yang: transfer from 0addr");
        require(recipient != address(0), "Yang: transfer to 0addr");
        require(amount > 0, "Transfer < 0");

        bool fromExcluded = _isExcluded[sender];
        bool toExcluded = _isExcluded[recipient];

        if (fromExcluded && !toExcluded) {
            _transferFromExcluded(sender, recipient, amount);
        } else if (!fromExcluded && toExcluded) {
            _transferToExcluded(sender, recipient, amount);
        } else if (!fromExcluded && !toExcluded) {
            _transferStandard(sender, recipient, amount);
        } else {
            _transferBothExcluded(sender, recipient, amount);
        }
    }

    function _transferStandard(
        address sender,
        address recipient,
        uint256 tokenAmount
    ) internal {
        (
            uint256 reflectionFee,
            uint256 transferedAmount,
            uint256 reflectedAmount,
            uint256 reflectedTransferAmount,
            uint256 reflectedFee
        ) = _getValues(tokenAmount);

        unchecked {
            _rOwned[sender] = _rOwned[sender] - reflectedAmount;
            _rOwned[recipient] = _rOwned[recipient] + reflectedTransferAmount;
        }

        uint256 remainingFee = _onTransfer(sender, reflectionFee);
        _absorbFee(reflectedFee, remainingFee);

        emit Transfer(sender, recipient, transferedAmount);
    }

    function _transferToExcluded(
        address sender,
        address recipient,
        uint256 tokenAmount
    ) internal {
        (
            uint256 reflectionFee,
            uint256 transferedAmount,
            uint256 reflectedAmount,
            ,
            uint256 reflectedFee
        ) = _getValues(tokenAmount);

        unchecked {
            _rOwned[sender] = _rOwned[sender] - reflectedAmount;
        }
        _tOwned[recipient] = _tOwned[recipient] + transferedAmount;

        uint256 remainingFee = _onTransfer(sender, reflectionFee);
        _absorbFee(reflectedFee, remainingFee);

        emit Transfer(sender, recipient, transferedAmount);
    }

    function _transferFromExcluded(
        address sender,
        address recipient,
        uint256 tokenAmount
    ) internal {
        (
            uint256 reflectionFee,
            uint256 transferedAmount,
            ,
            uint256 reflectedTransferAmount,
            uint256 reflectedFee
        ) = _getValues(tokenAmount);

        _tOwned[sender] = _tOwned[sender] - tokenAmount;
        unchecked {
            _rOwned[recipient] = _rOwned[recipient] + reflectedTransferAmount;
        }

        uint256 remainingFee = _onTransfer(sender, reflectionFee);
        _absorbFee(reflectedFee, remainingFee);

        emit Transfer(sender, recipient, transferedAmount);
    }

    function _transferBothExcluded(
        address sender,
        address recipient,
        uint256 tokenAmount
    ) internal {
        _tOwned[sender] = _tOwned[sender] - tokenAmount;
        _tOwned[recipient] = _tOwned[recipient] + tokenAmount;

        emit Transfer(sender, recipient, tokenAmount);
    }

    function _getValues(
        uint256 transferAmount
    )
        internal
        view
        returns (
            uint256 reflectionFee,
            uint256 transferedAmount,
            uint256 reflectedAmount,
            uint256 reflectedTransferAmount,
            uint256 reflectedFee
        )
    {
        reflectionFee = (transferAmount * TRANSFER_FEE_BP) / 10000;
        transferedAmount = transferAmount - reflectionFee;

        uint256 currentRate = _getRate();
        reflectedAmount = transferAmount * currentRate;
        reflectedFee = reflectionFee * currentRate;
        reflectedTransferAmount = reflectedAmount - reflectedFee;
    }

    function _absorbFee(uint256 rFee, uint256 tFee) internal {
        _rTotal = _rTotal - rFee;
        _tFeeTotal = _tFeeTotal + tFee;
    }

    function _getRate() internal view returns (uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply / tSupply;
    }

    function _getCurrentSupply() internal view returns (uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (
                _rOwned[_excluded[i]] > rSupply ||
                _tOwned[_excluded[i]] > tSupply
            ) return (_rTotal, _tTotal);
            rSupply = rSupply - _rOwned[_excluded[i]];
            tSupply = tSupply - _tOwned[_excluded[i]];
        }
        if (rSupply < _rTotal / _tTotal) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }

    /// @notice Overridable function triggering
    /// @dev The remaining reflectionFee will be actually reflected
    function _onTransfer(
        address sender,
        uint256 reflectionFee
    ) internal virtual returns (uint256 remainingFee) {}
}
