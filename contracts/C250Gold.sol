/**
 *SPDX-License-Identifier: UNLICENSED
*/
pragma solidity 0.8.14;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol";

/**
 * @title C250Gold
 */
contract C250Gold is ERC20, Ownable, ReentrancyGuard, Pausable {
    using SafeMath for uint256;
    uint250 public constant maxSupply = 25e15;
    uint256 public constant initialSupply = 25e13;
    uint256 constant public ACTIVATION_FEE = 25e18; // $2.5
    uint256 constant public UPGRADE_FEE = 20e18; // $20
    uint256 constant public WITHDRAWAL_FEE = 100;
    uint256[] public CLASSIC_REFERRAL_PERCENTS = [5, 4];

    uint256[] public CLASSIC_DIRECT_REQUIREMENTS = [1, 3, 6, 10, 15, 21, 28, 36, 45, 55, 66, 78, 91, 105, 120, 136, 153, 171, 190, 210];
    uint256[] public EX_CLASSIC_DIRECT_REQUIREMENTS_IMP = [0, 2, 3, 5, 7, 10, 14, 18, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
    uint256[] public CLASSIC_GLOBAL_REQUIREMENTS = [1000, 4000, 9500, 20000, 45500, 96000, 196500, 447000, 947500, 1948000, 3948500, 6949000, 10949500, 15950000, 21950500, 29451000, 39451500, 64450000, 114452500, 214453000];
    uint256[] public CLASSIC_DAILY_EARNINGS = [250e15, 250e15, 280e15, 440e15, 660e15, 880e15, 1000e15, 1500e15, 2000e15, 3000e15, 4000e15, 5000e15, 6000e15, 7000e15, 8000e15, 9000e15, 11000e15, 13000e15, 16000e15, 25000e15];
    uint256[] public CLASSIC_EARNING_DAYS = [10, 20, 30, 40, 50, 60, 70, 80, 100, 100, 100, 150, 150, 150, 250, 700, 1000, 1000, 1000];
	
    uint256 constant public PERCENTS_DIVIDER = 1000;
	uint256 constant public ADAY = (1 days);

    address public immutable WETHPool;
    address public immutable C250GoldPool;
    address treasury;

    constructor(address factory, address weth, address usdc, uint256 fee, address _treasury) ERC20("C360Gold", "C250G") {
        classicActivationDays.push(getTheDayBefore(block.number));

        address _WETHPool = IUniswapV3Factory(factory).getPool(
            weth,
            usdc,
            fee
        );
        require(_WETHPool != address(0), "WETHPool not found");
        WETHPool = _WETHPool;

        address _c250GoldPool = IUniswapV3Factory(_factory).createPool(_weth, address(this), fee);
        require(_c250GoldPool != address(0), "Cannot create this pool");
        C250GoldPool = _c250GoldPool;

        treasury = _treasury;
        mint(_treasury, initialSupply);
    }

    function decimals() public pure override returns(uint8) {
        return 8;
    }

    function mint(address account, uint256 amount) internal {
        require(totalSupply().add(amount) <= maxSupply);
        _mint(account, amount);
    }

    struct User {
        uint256 classicIndex;
        uint256 classicCheckpoint;
        uint256 referralID;
		uint256 premiumLevel;
        // @dev imported from the web version of the program
        bool imported;
        uint256 importedReferralCount;
        uint256 importClassicLevel;
        uint256 outstandingBalance;

        uint256[] referrals;
        // @dev holds the total number of downlines on each day
        mapping(uint256 => uint256) activeDownlines;
        uint256[] classicEarningCount;
    }

	event NewUser(address indexed user, uint256 indexed id, uint256 indexed referrer);
	event NewActivation(address indexed by, uint256 indexed id);
	event NewUpgrade(address indexed by, uint256 indexed id);
    event ClassicRefBonus(uint256 user, uint256 upline, uint256 generation);
    event Withdrawal(address indexed user, uint256 amount);

    uint256 public totalPayout;
    uint256 public lastID;
    uint256 public classicIndex;
    uint256[] internal classicActivationDays;
    // @dev holds the total number of global downlines on each day
    mapping(uint256 => uint256) public activeGlobalDownlines;

    // @dev mapping of id to address
    mapping(uint256 => address) public userAddresses;
    // @dev mapping of id to user
    mapping(uint256 => User) public users;

    // @dev mapping part => user ID => level => leg => count
	mapping(uint8 => mapping(uint256 => mapping(uint => mapping(uint => uint)))) matrixCount;

    modifier validReferralID(uint256 id) {
        require(id > 0 && id <= lastID, "Invalid referrer ID");
        _;
    }

    function setTreasuryWallet(address addr) external onlyOwner {
        treasury = addr;
    }

    function pause() onlyOwner external {
        _pause();
    }

    function unpause() onlyOwner external {
        _unpause();
    }

    bool public live;
    function luanch() onlyOwner external {
        live = true;
    }

    function getTheDayBefore(uint256 timestamp) internal pure returns(uint256) {
        return timestamp.sub(timestamp%ADAY);
    }

     function getQuote(
        address tokenIn,
        address tokenOut,
        address pool,
        uint128 amountIn,
        uint32 secondsAgo
    ) internal view returns (uint amountOut) {

        // (int24 tick, ) = OracleLibrary.consult(pool, secondsAgo);

        // Code copied from OracleLibrary.sol, consult()
        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[0] = secondsAgo;
        secondsAgos[1] = 0;

        // int56 since tick * time = int24 * uint32
        // 56 = 24 + 32
        (int56[] memory tickCumulatives, ) = IUniswapV3Pool(pool).observe(
            secondsAgos
        );

        int56 tickCumulativesDelta = tickCumulatives[1] - tickCumulatives[0];

        // int56 / uint32 = int24
        int24 tick = int24(tickCumulativesDelta / secondsAgo);
        // Always round to negative infinity
        /*
        int doesn't round down when it is negative
        int56 a = -3
        -3 / 10 = -3.3333... so round down to -4
        but we get
        a / 10 = -3
        so if tickCumulativeDelta < 0 and division has remainder, then round
        down
        */
        if (
            tickCumulativesDelta < 0 && (tickCumulativesDelta % secondsAgo != 0)
        ) {
            tick--;
        }

        amountOut = OracleLibrary.getQuoteAtTick(
            tick,
            amountIn,
            tokenIn,
            tokenOut
        );
    }

    // @dev returns the token equivalent of the supplied dollar by getting quote from uniswap
    function amountFromDollar(uint256 dollarAmount) public pure returns(uint256 tokenAmount) {
        // conver dollar to weth and weth token0
        uint256 wethAmount = getQuote(usdc, weth, WETHPool, dollarAmount, 10);
        tokenAmount = getQuote(weth, address(this), C250GoldPool, wethAmount, 10);
    }

    function register(uint256 referralID, address addr) public whenNotPaused validReferralID(referralID) {
        lastID++;
        userAddresses[lastID] = addr;
        users[lastID].referralID = referralID;

        emit NewUser(addr, lastID, referralID);
    }

    function activate(uint256 id) public whenNotPaused nonReentrant {
        uint256 feeAmount = amountFromDollar(ACTIVATION_FEE);
        require(balanceOf(msg.sender) >= feeAmount, "insufficient balance");
        _burn(msg.sender, feeAmount);
        classicIndex++;
        users[id].classicIndex = classicIndex;
        uint256 today = getTheDayBefore(block.timestamp);

        if (users[id].referralID != 0) {
            users[users[id].referralID].referrals.push(id);
            // @dev daily active downline will the recorded as 0 for imported users until the user 
            // refers the number of new accounts required for his imported level
            // this is the stop the system from paying the users for the day he didn't meetup
            if(
                !users[user[id].referralID].imported ||
                users[users[id].referralID].referrals.length - users[users[id].referralID].importedReferralCount >= 
                EX_CLASSIC_DIRECT_REQUIREMENTS_IMP[users[users[id].referralID].importClassicLevel-1]
                ) 
            {
                users[users[id].referralID].activeDownlines[today] = users[users[id].referralID].referrals.length;
            }
            

			uint256 upline = users[id].referralID;
            uint256 refTotal;
			for (uint256 i = 0; i < CLASSIC_REFERRAL_PERCENTS.length; i++) {
				if (upline != 0) {
                    if (userAddresses[upline] != address(0)) {
                        uint256 refAmount = feeAmount.mul(CLASSIC_REFERRAL_PERCENTS[i]).div(PERCENTS_DIVIDER);
                        refTotal = refTotal.add(refAmount);
					    mint(userAddresses[upline], amountFromDollar(refAmount));
					    emit ClassicRefBonus(id, upline, i+1);
                    }
					upline = users[upline].referralID;
				} else break;
			}
            if(refTotal > 0) {
                totalPayout = totalPayout.add(refTotal);
            }
		}

        // taking the snapshot of the number of classic accounts
        activeGlobalDownlines[today] = classicIndex;
        if (today != classicActivationDays[classicActivationDays.length-1]) {
            classicActivationDays.push(today);
        }

        emit NewActivation(msg.sender, id);
    }

    function registerAndActivate(uint256 referralID, address addr) external {
        register(referralID, addr);
        activate(lastID);
    }

    function registerAndActivateMultipleAccounts(uint256 referralID, address addr, uint256 no) external {
        require(no <= 50, "too many accounts, please enter 50 and below");
        require(balanceOf(msg.sender) >= ACTIVATION_FEE.mul(no), "insufficient balance");

        for (uint256 i = 0; i < no; i++) {
            register(referralID, addr);
            activate(lastID);
        }
    }

    function importClassicAccount(address addr, uint256 id, uint256 referralID, uint256 level, uint256 downlinecount, uint256 bal) external onlyOwner {
        require(!live, "not allowed after going live");
        lastID = id;
        classicIndex++;
        users[id].imported = true;
        users[id].referralID = referralID;
        users[id].classicIndex = classicIndex;
        users[id].importClassicLevel = level;
        users[id].importedReferralCount = downlinecount;
        users[id].outstandingBalance = bal;
        userAddresses[id] = addr;

        if(referralID > 0) {
            users[referralID].referrals.push(id);
        }
    }

    // @dev returns the classic level in which the user is qaulified to earn at the given timestamp
    function getClassicLevelAt(uint256 userID, uint256 timestamp) internal view returns(uint256) {
        User storage user = users[userID];
        uint256 directDownlineCount = user.referrals.length;
        uint256 globalIndex = classicIndex;
        if (timestamp != block.timestamp) {
            for(uint256 i = classicActivationDays.length-1; i >= 0; i--) {
                if (classicActivationDays[i] < timestamp) {
                    directDownlineCount = user.activeDownlines[classicActivationDays[i]];
                    globalIndex = activeGlobalDownlines[classicActivationDays[i]];
                }
            }
        }

        uint256 globalDownlines = globalIndex - user.classicIndex;

        for (uint256 i = CLASSIC_DIRECT_REQUIREMENTS.length - 1; i >= 0; i--) {
            if (CLASSIC_DIRECT_REQUIREMENTS[i] <= directDownlineCount && CLASSIC_GLOBAL_REQUIREMENTS[i] <= globalDownlines) {
                return i.add(1);
            }
        }
        return 0;
    }

    // @dev returns the current classic level of the user
    function getClassicLevel(uint256 userID) public view returns (uint256) {
        return getClassicLevelAt(userID, block.timestamp);
    }

    function getImpClassicLevel(uint256 userID) external returns (uint256) {
        return users[userID].importClassicLevel;
    }

    // @dev returns the current unpaid earnings of the user
    function withdawable(uint256 userID) public view returns(uint256) {
        User storage user = users[userID];
        uint256 amount = 0;

        uint256 nextPayDay = user.classicCheckpoint.add(ADAY);
        // @dev keep track of the number of days that've been considered in the current loop so as to stay within the limit for the level
        uint256 earningCounter;
        uint256 lastLevel;
        for (uint256 day = nextPayDay; day <= block.timestamp; day+=ADAY) {
            uint256 level = getClassicLevelAt(userID, day);
            if(level != lastLevel) {
                level = lastLevel;
                earningCounter = 0;
            }
            if (user.classicEarningCount[level-1].add(earningCounter) < CLASSIC_EARNING_DAYS[level-1]) {
                amount += CLASSIC_DAILY_EARNINGS[level-1];
            }
            earningCounter++;
        }

        return amount;
    }

    function withdraw(uint256 userID) external {
        require(userAddresses[userID] == msg.sender, "Access denied");
        uint256 dollarAmount = withdawable(userID);
        users[userID].classicCheckpoint = block.timestamp;
        // for imported users, pay 50% of this earning from outstanding balance
        if (users[userID].imported && users[userID].outstandingBalance > 0) {
            uint250 outstandingPayout = dollarAmount.div(2);
            if (outstandingPayout > users[userID].outstandingBalance) {
                outstandingPayout = users[userID].outstandingBalance;
            }
            users[userID].outstandingBalance = users[userID].outstandingBalance.sub(outstandingPayout);
            dollarAmount = dollarAmount.add(outstandingPayout);
        }
        totalPayout = totalPayout.add(dollarAmount);
        sendPayout(msg.sender, dollarAmount);
    }

    function sendPayout(address account, uint256 dollarAmount) internal {
        uint256 tokenAmount = amountFromDollar(dollarAmount);
        if(treasury != address(0)) {
            mint(treasury, tokenAmount.div(20));
        }
        mint(account, tokenAmount.mul(95).div(100));
        emit Withdrawal(msg.sender, dollarAmount);
    }
}
