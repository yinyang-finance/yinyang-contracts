// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "solmate/auth/Owned.sol";
import "./YinYang.sol";
import "./LiquidityAdder.sol";
import "./Zen.sol";
import "./Garden.sol";
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

    address public router;

    YinYang public yin;
    YinYang public yang;
    Zen public zen;
    Garden public garden;

    EpochInfo[] history;
    address public currentTarget = address(0);
    mapping(address => uint256) public tokenIsProposed;
    address[] public proposedTokens;
    uint256 public numberProposedTokens;
    mapping(address => uint256) public voices;
    mapping(address => uint256) public shares;
    mapping(address => address) public votersToken;
    mapping(address => uint256) public votersEpoch;

    mapping(address => AccountInfo) public tokenAccounts;
    mapping(address => mapping(address => uint256)) public userAccounts;
    mapping(uint256 => mapping(address => uint256)) public participations;
    mapping(address => address[]) private userTokens;
    mapping(address => uint256) private lastUpdate;

    event Withdraw(address indexed user, address token, uint256 amount);
    event Harvest(address indexed user, uint256 amount);

    constructor(
        address _owner,
        uint256 start,
        uint256 _epochDuration,
        YinYang _yin,
        YinYang _yang,
        Zen _zen,
        address _router
    ) Owned(_owner) TurnstileRegisterEntry() {
        epochDuration = _epochDuration;
        epochStart = start;
        origin = start;

        _addProposedToken(address(0));

        yin = _yin;
        yang = _yang;
        zen = _zen;
        note = IBaseV1Router(_router).note();
        wcanto = IBaseV1Router(_router).wcanto();
        router = _router;

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
    /// The proposed token should have a BNB LP on Pancake swap, else the harvest will not work.
    /// This is checked by the UI.
    function voteForNextTarget(address proposition, uint256 amount) public {
        uint256 start = epochStart;

        if (votersEpoch[msg.sender] == start) {
            // The user has already voted
            uint256 oldAmount = participations[history.length][msg.sender];
            address oldToken = votersToken[msg.sender];
            // Remove voices from the old proposition
            voices[oldToken] = voices[oldToken] - oldAmount;
            shares[oldToken] = shares[oldToken] - oldAmount;
            // Update infos
            participations[history.length][msg.sender] = oldAmount + amount;
        } else {
            // Check for pending shgares due to skipped epoch
            _updateUserAccount();
            votersEpoch[msg.sender] = start;
            participations[history.length][msg.sender] =
                participations[history.length][msg.sender] +
                amount;
        }

        // Add voices to the new proposition
        votersToken[msg.sender] = proposition;
        uint256 usedAmount = participations[history.length][msg.sender];
        voices[proposition] = voices[proposition] + usedAmount;
        shares[proposition] = shares[proposition] + usedAmount;

        zen.mintTo(msg.sender, amount);

        // Update the list of voted tokens if needed
        if (tokenIsProposed[proposition] != start) {
            _addProposedToken(proposition);
        }
    }

    // Can be called once per epoch to sell collected tokens to buy the elected token
    function harvest() public {
        require(isHarvestable(), "PeaceMaster: cannot harvest");

        uint256 epochsPast = block.timestamp - epochStart / epochDuration;
        epochStart = epochStart + epochDuration * epochsPast;

        currentTarget = getWinner();
        uint256 spentShares = shares[currentTarget];
        tokenAccounts[currentTarget].shares =
            tokenAccounts[currentTarget].shares +
            spentShares;
        history.push(
            EpochInfo({
                startTime: epochStart,
                result: ProposalInfo({
                    token: currentTarget,
                    voices: voices[currentTarget],
                    shares: spentShares
                })
            })
        );

        _cleanProposedTokens();
        _addProposedToken(address(0));

        if (currentTarget == address(0)) {
            _updateUserAccount();
            emit Harvest(msg.sender, 0);
            return;
        }

        // Market sell Yin Yang for the target
        if (yin.balanceOf(address(this)) > 0) {
            IBaseV1Router.route[] memory routes = new IBaseV1Router.route[](2);
            routes[0].from = address(yin);
            routes[0].to = address(note);
            routes[0].stable = false;
            routes[1].from = address(note);
            routes[1].to = address(wcanto);
            routes[1].stable = false;

            IBaseV1Router(router).swapExactTokensForTokens(
                yin.balanceOf(address(this)),
                0,
                routes,
                address(this),
                block.timestamp + 360
            );
        }

        if (yang.balanceOf(address(this)) > 0) {
            IBaseV1Router.route[] memory routes = new IBaseV1Router.route[](2);
            routes[0].from = address(yang);
            routes[0].to = address(wcanto);
            routes[0].stable = false;

            IBaseV1Router(router).swapExactTokensForTokens(
                yang.balanceOf(address(this)),
                0,
                routes,
                address(this),
                block.timestamp + 360
            );
        }

        if (currentTarget != wcanto) {
            IBaseV1Router.route[] memory routes = new IBaseV1Router.route[](2);
            routes[0].from = address(wcanto);
            routes[0].to = address(currentTarget);
            routes[0].stable = false;

            IBaseV1Router(router).swapExactTokensForTokens(
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
        _updateUserAccount();

        emit Harvest(msg.sender, tokenAccounts[currentTarget].amount);
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
            voices[proposedTokens[index]],
            shares[proposedTokens[index]]
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
            if (voices[proposedTokens[i]] > maxVoices) {
                maxVoices = voices[proposedTokens[i]];
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

    /*//////////////////////////////////////////////////////////////
                             INTERNAL LOGIC
    //////////////////////////////////////////////////////////////*/

    function _updateUserAccount() internal {
        for (uint256 i = lastUpdate[msg.sender]; i < history.length; i++) {
            if (participations[i][msg.sender] > 0) {
                if (history[i].result.token == address(0)) {
                    // Epoch was skipped, transfer shares to next round
                    participations[i + 1][msg.sender] = participations[i][
                        msg.sender
                    ];
                } else {
                    userTokens[msg.sender].push(history[i].result.token);
                    userAccounts[msg.sender][history[i].result.token] =
                        userAccounts[msg.sender][history[i].result.token] +
                        participations[i][msg.sender];
                }
                participations[i][msg.sender] = 0;
            }
            lastUpdate[msg.sender] = i + 1;
        }
    }

    function _cleanProposedTokens() internal {
        while (proposedTokens.length > 0) {
            proposedTokens.pop();
        }
    }

    function _addProposedToken(address token) internal {
        tokenIsProposed[token] = epochStart;
        proposedTokens.push(token);
    }
}
