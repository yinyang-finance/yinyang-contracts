// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "solmate/auth/Owned.sol";
import "./YinYang.sol";
import "./Zen.sol";
import "./Garden.sol";
import "./ISwap.sol";
import "./TurnstileRegisterEntry.sol";

/// @author Dodecahedr0x
/// @title The Temple of YinYang
/// @notice This contract manages collected fees
contract Temple is Owned, TurnstileRegisterEntry {
    struct VoterInfo {
        uint256 epoch;
        address token;
        uint256 voices;
    }

    struct EpochInfo {
        uint256 startTime;
        ProposalInfo result;
    }

    struct ProposalInfo {
        address token;
        uint256 voices;
        uint256 shares;
    }

    struct AccountInfo {
        uint256 amount;
        uint256 shares;
    }

    struct ShareInfo {
        address token;
        uint8 decimals;
        uint256 amount;
    }

    uint256 public epochDuration;
    uint256 public epochStart;
    uint256 public origin;

    address public wcanto;
    address public note;

    IBaseV1Router public router;

    YinYang public yin;
    YinYang public yang;
    Zen public zen;
    Garden public garden;

    EpochInfo[] history;
    address public currentTarget = address(0);
    mapping(address => uint256) public tokenIsProposed;
    address[] public proposedTokens;
    uint256 public numberProposedTokens;
    /// @notice Amount of voices for each proposed token at a given epoch
    mapping(uint256 => mapping(address => uint256)) public voices;
    /// @notice Total number of shares that voted for an epoch
    uint256 public shares;
    mapping(address => address) public votersToken;
    mapping(address => uint256) public votersEpoch;

    mapping(address => AccountInfo) public tokenAccounts;
    mapping(address => mapping(address => uint256)) public userAccounts;
    mapping(uint256 => mapping(address => uint256)) public participations;
    mapping(address => address[]) internal userTokens;
    mapping(address => uint256) internal lastUpdate;

    event Withdraw(address indexed user, address token, uint256 amount);
    event Harvest(address indexed user, uint256 amount);

    constructor(
        address _owner,
        uint256 start,
        uint256 _epochDuration,
        YinYang _yin,
        YinYang _yang,
        Zen _zen,
        address _note,
        address _router
    ) Owned(_owner) TurnstileRegisterEntry() {
        epochDuration = _epochDuration;
        epochStart = start;
        origin = start;

        _addProposedToken(address(0));

        yin = _yin;
        yang = _yang;
        zen = _zen;
        note = _note;
        wcanto = IBaseV1Router(_router).WETH();
        router = IBaseV1Router(_router);

        yin.approve(_router, type(uint256).max);
        yang.approve(_router, type(uint256).max);
        ERC20(yin.quote()).approve(_router, type(uint256).max);
        ERC20(yang.quote()).approve(_router, type(uint256).max);
    }

    function setGarden(Garden _garden) external onlyOwner {
        garden = _garden;
    }

    function mintZen(address recipient, uint256 amount) external {
        require(msg.sender == address(garden), "!Garden");
        zen.mintTo(recipient, amount);
    }

    /// @notice Exclude an account from reflections and burns. Used to protect distribution farms
    function excludeAccount(address account) internal {
        yin.excludeAccount(account);
        yang.excludeAccount(account);
    }

    /// @notice Votes for a token. If a vote has already been cast, all voices go to the new choice.
    /// The proposed token should have a WCanto LP on CantoDex, else the harvest will not work.
    /// This is checked by the UI.
    function voteForNextTarget(address proposition, uint256 amount) public {
        uint256 start = epochStart;
        uint256 epoch = history.length;

        if (votersEpoch[msg.sender] == start) {
            // The user has already voted
            uint256 oldAmount = participations[epoch][msg.sender];
            address oldToken = votersToken[msg.sender];
            // Remove voices from the old proposition
            voices[epoch][oldToken] -= oldAmount;
            shares -= oldAmount;
            // Update infos
            participations[epoch][msg.sender] = oldAmount + amount;
        } else {
            // Check for pending shares
            _updateUserAccount(msg.sender, epoch);

            votersEpoch[msg.sender] = start;
            participations[epoch][msg.sender] += amount;
        }

        // Add voices to the new proposition
        votersToken[msg.sender] = proposition;
        uint256 usedAmount = participations[epoch][msg.sender];
        voices[epoch][proposition] += usedAmount;
        shares += usedAmount;

        zen.burnFrom(msg.sender, amount);

        // Update the list of voted tokens if needed
        if (tokenIsProposed[proposition] != start) {
            _addProposedToken(proposition);
        }
    }

    // Can be called once per epoch to sell collected tokens to buy the elected token
    function harvest() public {
        require(isHarvestable(), "!harvestable");

        uint256 epochsPast = (block.timestamp - epochStart) / epochDuration;
        epochStart = epochStart + epochDuration * epochsPast;

        currentTarget = getWinner();
        tokenAccounts[currentTarget].shares =
            tokenAccounts[currentTarget].shares +
            shares;
        history.push(
            EpochInfo({
                startTime: epochStart,
                result: ProposalInfo({
                    token: currentTarget,
                    voices: voices[history.length][currentTarget],
                    shares: shares
                })
            })
        );
        shares = 0;

        delete proposedTokens;
        _addProposedToken(address(0));

        if (currentTarget == address(0)) {
            _updateUserAccount(msg.sender, history.length);
            emit Harvest(msg.sender, 0);
            return;
        }

        // Market sell Yin Yang for the target
        if (yin.balanceOf(address(this)) > 0) {
            address[] memory routes = new address[](3);
            routes[0] = address(yin);
            routes[1] = address(note);
            routes[2] = address(wcanto);

            IBaseV1Router(router)
                .swapExactTokensForTokensSupportingFeeOnTransferTokens(
                    yin.balanceOf(address(this)),
                    0,
                    routes,
                    address(this),
                    block.timestamp + 360
                );
        }

        if (yang.balanceOf(address(this)) > 0) {
            address[] memory routes = new address[](2);
            routes[0] = address(yang);
            routes[1] = address(wcanto);

            IBaseV1Router(router)
                .swapExactTokensForTokensSupportingFeeOnTransferTokens(
                    yang.balanceOf(address(this)),
                    0,
                    routes,
                    address(this),
                    block.timestamp + 360
                );
        }

        if (currentTarget != wcanto) {
            address[] memory routes = new address[](2);
            routes[0] = address(wcanto);
            routes[1] = address(currentTarget);

            IBaseV1Router(router)
                .swapExactTokensForTokensSupportingFeeOnTransferTokens(
                    ERC20(wcanto).balanceOf(address(this)),
                    0,
                    routes,
                    address(this),
                    block.timestamp + 360
                );
        }

        tokenAccounts[currentTarget].amount = ERC20(currentTarget).balanceOf(
            address(this)
        );
        _updateUserAccount(msg.sender, history.length);

        emit Harvest(msg.sender, tokenAccounts[currentTarget].amount);
    }

    function claimVoterShare(uint256 i) public {
        _updateUserAccount(msg.sender, history.length);
        ShareInfo[] memory s = pendingVoterShares(msg.sender);
        _claimSingleEpoch(s, i);
    }

    function claimAllVoterShares() public {
        _updateUserAccount(msg.sender, history.length);
        ShareInfo[] memory s = pendingVoterShares(msg.sender);
        for (uint256 i = 0; i < s.length; i++) {
            _claimSingleEpoch(s, i);
        }
    }

    function updateUserAccount(uint256 end) external {
        _updateUserAccount(msg.sender, end);
    }

    /*//////////////////////////////////////////////////////////////
                             UI GETTERS
    //////////////////////////////////////////////////////////////*/

    function getPropositionsLength() external view returns (uint256) {
        return proposedTokens.length;
    }

    function getProposition(
        uint256 index
    ) external view returns (address, uint256, uint256) {
        return (
            proposedTokens[index],
            voices[history.length][proposedTokens[index]],
            shares
        );
    }

    function getHistoryLength() external view returns (uint256 length) {
        return history.length;
    }

    function getHistory(
        uint256 index
    ) external view returns (uint256, address, uint256, uint256) {
        require(index < history.length, "hystory index out of range");
        return (
            history[index].startTime,
            history[index].result.token,
            history[index].result.voices,
            history[index].result.shares
        );
    }

    function getWinner() public view returns (address) {
        uint256 maxVoices = 0;
        address winner = address(0);
        for (uint256 i = 0; i < proposedTokens.length; i++) {
            if (voices[history.length][proposedTokens[i]] > maxVoices) {
                maxVoices = voices[history.length][proposedTokens[i]];
                winner = proposedTokens[i];
            }
        }
        return winner;
    }

    function getUserVote(
        address user
    ) public view returns (address token, uint256 userShares) {
        if (updatesMissing(user) > 0) {
            return (address(0), 0);
        } else {
            return (votersToken[user], participations[history.length][user]);
        }
    }

    function isHarvestable() public view returns (bool) {
        return block.timestamp > epochStart + epochDuration;
    }

    function updatesMissing(address user) public view returns (uint256) {
        return history.length - lastUpdate[user];
    }

    function pendingVoterShares(
        address user
    ) internal view returns (ShareInfo[] memory) {
        ShareInfo[] memory s = new ShareInfo[](userTokens[user].length);
        for (uint256 i = 0; i < userTokens[user].length; i++) {
            address token = userTokens[user][i];
            s[i] = ShareInfo({
                token: token,
                decimals: ERC20(token).decimals(),
                amount: (tokenAccounts[token].amount *
                    userAccounts[user][token]) / tokenAccounts[token].shares
            });
        }
        return s;
    }

    /*//////////////////////////////////////////////////////////////
                             INTERNAL LOGIC
    //////////////////////////////////////////////////////////////*/

    function _updateUserAccount(address user, uint256 end) internal {
        for (uint256 i = lastUpdate[user]; i < end; i++) {
            if (participations[i][user] > 0) {
                // Epoch was skipped, transfer shares to next round
                participations[i + 1][user] = participations[i][user];

                userTokens[user].push(history[i].result.token);
                userAccounts[user][history[i].result.token] =
                    userAccounts[user][history[i].result.token] +
                    participations[i][user];

                participations[i][user] = 0;
            }
            lastUpdate[user] = i + 1;
        }
    }

    function _addProposedToken(address token) internal {
        require(proposedTokens.length < 50, "too many propositions");
        tokenIsProposed[token] = epochStart;
        proposedTokens.push(token);
    }

    function _claimSingleEpoch(ShareInfo[] memory s, uint256 i) internal {
        uint256 contractBalance = ERC20(s[i].token).balanceOf(address(this));
        if (s[i].amount > contractBalance) {
            s[i].amount = contractBalance; // For rounding errors
        }

        tokenAccounts[s[i].token].shares =
            tokenAccounts[s[i].token].shares -
            userAccounts[msg.sender][s[i].token];
        tokenAccounts[s[i].token].amount =
            tokenAccounts[s[i].token].amount -
            s[i].amount;

        userAccounts[msg.sender][s[i].token] = 0;

        userTokens[msg.sender][i] = userTokens[msg.sender][
            userTokens[msg.sender].length - 1
        ];
        userTokens[msg.sender].pop();
        ERC20(s[i].token).transfer(msg.sender, s[i].amount);
        emit Withdraw(msg.sender, s[i].token, s[i].amount);
    }
}
