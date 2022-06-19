/**
 *SPDX-License-Identifier: UNLICENSED
 */
// pragma solidity 0.7.6;
pragma solidity 0.8.14;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol";

/**
 * @title C250Gold
 */
contract C250Gold is ERC20, Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    uint256 public constant MAX_SUPPLY = 250000000 * 1e18;
    uint256 public constant INITIAL_SUPPLY = 250000 * 1e18;
    uint256 public constant ACTIVATION_FEE = 25e18; // $2.5
    uint256 public constant UPGRADE_FEE = 20e18; // $20
    uint256 public constant WITHDRAWAL_FEE = 100;
    uint256[] public CLASSIC_REFERRAL_PERCENTS = [5, 4];

    uint256[] public CLASSIC_DIRECT_REQUIREMENTS = [
        1,
        3,
        6,
        10,
        15,
        21,
        28,
        36,
        45,
        55,
        66,
        78,
        91,
        105,
        120,
        136,
        153,
        171,
        190,
        210
    ];
    uint256[] public EX_CLASSIC_DIRECT_REQUIREMENTS_IMP = [
        0,
        2,
        3,
        5,
        7,
        10,
        14,
        18,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0
    ];
    uint256[] public CLASSIC_GLOBAL_REQUIREMENTS = [
        1000,
        4000,
        9500,
        20000,
        45500,
        96000,
        196500,
        447000,
        947500,
        1948000,
        3948500,
        6949000,
        10949500,
        15950000,
        21950500,
        29451000,
        39451500,
        64450000,
        114452500,
        214453000
    ];
    uint256[] public CLASSIC_DAILY_EARNINGS = [
        250e15,
        250e15,
        280e15,
        440e15,
        660e15,
        880e15,
        1000e15,
        1500e15,
        2000e15,
        3000e15,
        4000e15,
        5000e15,
        6000e15,
        7000e15,
        8000e15,
        9000e15,
        11000e15,
        13000e15,
        16000e15,
        25000e15
    ];
    uint256[] public CLASSIC_EARNING_DAYS = [
        10,
        20,
        30,
        40,
        50,
        60,
        70,
        80,
        100,
        100,
        100,
        150,
        150,
        150,
        250,
        700,
        1000,
        1000,
        1000
    ];

    uint256 public constant PERCENTS_DIVIDER = 1000;
    uint256 public constant ADAY = (1 days);

    address public immutable C250GoldPool;
    address usdc;
    address treasury;

    address premiumContractAddress;

    constructor(
        address factory,
        address _usdc,
        uint24 fee,
        address _treasury
    ) ERC20("C360Gold", "C250G") {
        classicActivationDays.push(getTheDayBefore(block.number));

        address _c250GoldPool = IUniswapV3Factory(factory).createPool(
            usdc,
            address(this),
            fee
        );
        require(_c250GoldPool != address(0), "Cannot create this pool");
        C250GoldPool = _c250GoldPool;

        treasury = _treasury;
        mint(_treasury, INITIAL_SUPPLY);

        _register(0, treasury);
    }

    function decimals() public pure override returns (uint8) {
        return 18;
    }

    function mint(address account, uint256 amount) internal {
        require(totalSupply().add(amount) <= MAX_SUPPLY);
        _mint(account, amount);
    }

    struct User {
        uint256 classicIndex;
        uint256 classicCheckpoint;
        uint256 referralID;
        uint256 uplineID;
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

    event NewUser(
        address indexed user,
        uint256 indexed id,
        uint256 indexed referrer
    );
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
    // @dev list of accounts associated with an address
    mapping(address => uint256[]) public userAccounts;

    // @dev mapping part => user ID => level => leg => count
    mapping(uint8 => mapping(uint256 => mapping(uint256 => mapping(uint256 => uint256)))) matrixCount;

    modifier validReferralID(uint256 id) {
        require(id > 0 && id <= lastID, "Invalid referrer ID");
        _;
    }

    function setTreasuryWallet(address addr) external onlyOwner {
        treasury = addr;
    }

    bool public live;

    function launch() external onlyOwner {
        live = true;
    }

    function setPremiumContractAddress(address addr) external onlyOwner {
        premiumContractAddress = _addr;
    }

    function getTheDayBefore(uint256 timestamp)
        internal
        pure
        returns (uint256)
    {
        return timestamp.sub(timestamp % ADAY);
    }

    function getQuote(
        address tokenIn,
        address tokenOut,
        address pool,
        uint128 amountIn,
        uint32 secondsAgo
    ) internal view returns (uint256 amountOut) {
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
    function amountFromDollar(uint256 dollarAmount)
        public
        view
        returns (uint256 tokenAmount)
    {
        tokenAmount = getQuote(
            usdc,
            address(this),
            C250GoldPool,
            uint128(dollarAmount),
            10
        );
    }

    function _register(
        uint256 referralID,
        uint256 uplineID,
        address addr
    ) internal {
        lastID++;
        userAddresses[lastID] = addr;
        users[lastID].referralID = referralID;
        // @dev if an upline is supplied, it must be a premium account. ID 1 is premium by default
        if (uplineID > 0) {
            require(
                accountIsInPremium(uplineID),
                "Upline ID not a premium account"
            );
            users[lastID].uplineID = uplineID;
        }
        userAccounts[addr].push(lastID);

        emit NewUser(addr, lastID, referralID);
    }

    function register(
        uint256 referralID,
        uint256 uplineID,
        address addr
    ) public validReferralID(referralID) {
        require(live, "Not started");
        require(
            userAccounts[addr].length == 0,
            "Already registered, user add account"
        );
        _register(referralID, uplineID, addr);
    }

    function addAccount(
        uint256 referralID,
        uint256 uplineID,
        address addr
    ) external validReferralID(referralID) {
        require(live, "Not started");
        require(
            userAccounts[addr].length != 0,
            "Account not found, please register"
        );
        _register(referralID, uplineID, addr);
    }

    function activate(uint256 id) public nonReentrant {
        require(live, "Not started");
        require(userAddresses[id] != address(0), "Account not registered");
        require(users[id].classicIndex == 0, "Already activated");
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
            if (
                !users[users[id].referralID].imported ||
                users[users[id].referralID].referrals.length -
                    users[users[id].referralID].importedReferralCount >=
                EX_CLASSIC_DIRECT_REQUIREMENTS_IMP[
                    users[users[id].referralID].importClassicLevel - 1
                ]
            ) {
                users[users[id].referralID].activeDownlines[today] = users[
                    users[id].referralID
                ].referrals.length;
            }

            uint256 upline = users[id].referralID;
            uint256 refTotal;
            for (uint256 i = 0; i < CLASSIC_REFERRAL_PERCENTS.length; i++) {
                if (upline != 0) {
                    if (userAddresses[upline] != address(0)) {
                        uint256 refAmount = feeAmount
                            .mul(CLASSIC_REFERRAL_PERCENTS[i])
                            .div(PERCENTS_DIVIDER);
                        refTotal = refTotal.add(refAmount);
                        mint(
                            userAddresses[upline],
                            amountFromDollar(refAmount)
                        );
                        emit ClassicRefBonus(id, upline, i + 1);
                    }
                    upline = users[upline].referralID;
                } else break;
            }
            if (refTotal > 0) {
                totalPayout = totalPayout.add(refTotal);
            }
        }

        // taking the snapshot of the number of classic accounts
        activeGlobalDownlines[today] = classicIndex;
        if (today != classicActivationDays[classicActivationDays.length - 1]) {
            classicActivationDays.push(today);
        }

        emit NewActivation(msg.sender, id);
    }

    function registerAndActivate(uint256 referralID, address addr) external {
        register(referralID, addr);
        activate(lastID);
    }

    function registerAndActivateMultipleAccounts(
        uint256 referralID,
        address addr,
        uint256 no
    ) external {
        require(no <= 50, "too many accounts, please enter 50 and below");
        require(
            balanceOf(msg.sender) >= ACTIVATION_FEE.mul(no),
            "insufficient balance"
        );

        for (uint256 i = 0; i < no; i++) {
            register(referralID, addr);
            activate(lastID);
        }
    }

    function importClassicAccount(
        address addr,
        uint256 id,
        uint256 referralID,
        uint256 level,
        uint256 downlinecount,
        uint256 bal
    ) external onlyOwner {
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

        if (referralID > 0) {
            users[referralID].referrals.push(id);
        }
    }

        // @dev returns the current unpaid earnings of the user
    function withdawable(uint256 userID) public view returns (uint256) {
        User storage user = users[userID];
        uint256 amount = 0;

        uint256 nextPayDay = user.classicCheckpoint.add(ADAY);
        // @dev keep track of the number of days that've been considered in the current loop so as to stay within the limit for the level
        uint256 earningCounter;
        uint256 lastLevel;
        for (uint256 day = nextPayDay; day <= block.timestamp; day += ADAY) {
            uint256 level = getClassicLevelAt(userID, day);
            if (level != lastLevel) {
                level = lastLevel;
                earningCounter = 0;
            }
            if (
                user.classicEarningCount[level - 1].add(earningCounter) <
                CLASSIC_EARNING_DAYS[level - 1]
            ) {
                amount += CLASSIC_DAILY_EARNINGS[level - 1];
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
            uint256 outstandingPayout = dollarAmount.div(2);
            if (outstandingPayout > users[userID].outstandingBalance) {
                outstandingPayout = users[userID].outstandingBalance;
            }
            users[userID].outstandingBalance = users[userID]
                .outstandingBalance
                .sub(outstandingPayout);
            dollarAmount = dollarAmount.add(outstandingPayout);
        }
        totalPayout = totalPayout.add(dollarAmount);
        sendPayout(msg.sender, dollarAmount);
    }

    function sendPayout(address account, uint256 dollarAmount) internal {
        uint256 tokenAmount = amountFromDollar(dollarAmount);
        uint256 fee = tokenAmount.mul(WITHDRAWAL_FEE).div(PERCENTS_DIVIDER);
        if (treasury != address(0)) {
            mint(treasury, fee);
        }
        mint(account, tokenAmount.sub(fee));
        emit Withdrawal(msg.sender, dollarAmount);
    }

    function getAccounts(address addr)
        external
        view
        returns (uint256[] memory)
    {
        return userAccounts[addr];
    }

    // @dev returns the classic level in which the user is qaulified to earn at the given timestamp
    function getClassicLevelAt(uint256 userID, uint256 timestamp)
        internal
        view
        returns (uint256)
    {
        User storage user = users[userID];
        uint256 directDownlineCount = user.referrals.length;
        uint256 globalIndex = classicIndex;
        if (timestamp != block.timestamp) {
            for (uint256 i = classicActivationDays.length - 1; i >= 0; i--) {
                if (classicActivationDays[i] < timestamp) {
                    directDownlineCount = user.activeDownlines[
                        classicActivationDays[i]
                    ];
                    globalIndex = activeGlobalDownlines[
                        classicActivationDays[i]
                    ];
                }
            }
        }

        uint256 globalDownlines = globalIndex - user.classicIndex;

        for (uint256 i = CLASSIC_DIRECT_REQUIREMENTS.length - 1; i >= 0; i--) {
            if (
                CLASSIC_DIRECT_REQUIREMENTS[i] <= directDownlineCount &&
                CLASSIC_GLOBAL_REQUIREMENTS[i] <= globalDownlines
            ) {
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

    function activationFeeInToken() external view returns (uint256) {
        return amountFromDollar(ACTIVATION_FEE);
    }

    function getUser(uint256 userID)
        external
        view
        returns (
            address addr,
            uint256 downlines,
            uint256 lastID.sub(users[userID].classicIndex);,
            uint256 classicLevel,
            uint256 classicCheckpoint,
            uint256 referralID,
            uint256 premiumLevel
        )
    {
        addr = userAddresses[userID];
        downlines = users[userID].referrals.length;
        globalDownlines = getGlobalDownlines(userID);
        classicLevel = getClassicLevel(userID);
        classicCheckpoint = users[userID].classicCheckpoint;
        referralID = users[userID].referralID;
        premiumLevel = users[userID].premiumLevel;
    }

    // //////// //////// /* C250 Premuin *\ \\\\\\\\ \\\\\\\\

    struct Matrix {
        bool registered;
        uint256 uplineID;
        uint250 left;
        uint256 right;
        uint256 block;
    }

    struct LevelConfig {
        uint256 perDropEarning;
        uint256 paymentGeneration;
        uint256 numberOfPayments;
    }

    event PremiumReferralPayout(
        uint256 indexed userID,
        uint256 indexed referralID,
        uint256 amount
    );

    event MatrixPayout(
        uint256 indexed userID,
        uint256 indexed fromID,
        uint256 amount
    );

    event NewLevel(uint256 indexed userID, uint256 indexed level);

    // @dev user's matric for each part
    mapping(uint256 => mapping(uint256 => Matrix)) matrices;

    mapping(uint256 => LevelConfig) levelConfigurations;

    // @dev holds number of payments received by a user in each level
    mapping(uint256 => uint256) matrixPayments;

    function upgradeToPremium(uint256 userID, uint256 random) external {
        require(live, "Not launched yet");
        require(userID > 0 && userID <= lastID, "Invalid ID");
        require(
            balanceOf(msg.sender) >= amountFromDollar(UPGRADE_FEE),
            "Insufficient balance"
        );

        User memory user = users[userID];

        _burn(msg.sender, amountFromDollar(UPGRADE_FEE));

        uint256 sponsorID = getPremiumSponsor(userID, 0);
        sendPayout(
            userAddresses[sponsorID],
            amountFromDollar(UPGRADE_FEE.div(2))
        );
        emit PremiumReferralPayout(
            sponsorID,
            userID,
            amountFromDollar(UPGRADE_FEE.div(2))
        );

        uint256 uplineID = sponsorID;
        if (user.uplineID > 0) {
            uplineID = user.uplineID;
        }

        uint256 matrixUpline = getMatrixPositionUplineID(uplineID, 1, random);
        matrices[userID][1].registered = true;
        matrices[userID][1].uplineID = matrixUpline;
        matrices[userID][1].block = matrices[matrixUpline][1].block + 1;
        if (matrices[matrixUpline][1].left == 0) {
            matrices[matrixUpline][1].left = userID;
        } else {
            matrices[matrixUpline][1].right = userID;
            moveToNextLevel(matrixUpline);
        }

        users[userID].premiumLevel = 1;

        sendMatrixPayout(userID, 1);
    }

    function accountIsInPremium(userID) private view returns (bool) {
        return userID == 1 || users[userID].premiumLevel > 0;
    }

    function getPremiumSponsor(uint256 userID, uint256 callCount)
        internal
        view
        returns (uint256)
    {
        if (callCount >= 10) {
            return 1;
        }
        if (accountIsInPremium(users[userID].referralID)) {
            return users[userID].referralID;
        }

        return getPremiumSponsor(users[userID].referralID, callCount + 1);
    }

    // @dev returns the upline of the user in the supplied part.
    // part must be 2 and above.
    // part 1 should use the get getPremiumSponsor
    function getUplineInPart(
        uint256 userID,
        uint256 part,
        int256 callDept
    ) private view returns (uint256) {
        require(part > 1, "Invalid part for getUplineInPart");
        if (matrices[userID][part].registered) {
            return matrices[userID][part].uplineID;
        }

        uint256 p1up = matrices[userID][1].uplineID;
        if (matrices[p1up][part].registered) {
            return p1up;
        }

        if (callDept >= 50) {
            return 1;
        }

        return getUplineInPart(p1Up, part, callDept + 1);
    }

    // @dev return user ID that has space in the matrix of the supplied upline ID
    // @dev uplineID must be a premium account in the supplied part
    function getMatrixPositionUplineID(
        uint256 uplineID,
        uint256 part,
        uint256 random
    ) private view returns (uint256) {
        require(matrices[uplineID][part].registered, "Upline not in part");

        if (hasEmptyLegs(uplineID, part)) {
            return uplineID;
        }

        uint256[] baseUplines;
        baseUplines.push(uplineID);

        for (uint256 j = 1; j <= 10; j++) {
            baseUplines = getAllLegs(baseUplines, part);
            for (uint256 i = 0; i < baseUplines.length; i++) {
                if (hasEmptyLegs(baseUplines[i], part)) {
                    return baseUplines[i];
                }
            }
        }
        uint256 randomIndex = random % baseUplines.length;
        return
            getMatrixPositionUplineID(baseUplines[randomIndex], part, random);
    }

    function hasEmptyLegs(uint256 userID, uint256 part) private returns (bool) {
        return
            matrices[userID][part].left == 0 ||
            matrices[userID][part].left == 0;
    }

    function getAllLegs(uint256[] uplines, uint256 part) returns (uint256[]) {
        uint256[] res;
        for (uint256 i = 0; i < uplines.length; i++) {
            if (matrices[uplines[i]][part].left > 0) {
                res.push(matrices[uplines[i]][part].left);
            }

            if (matrices[uplines[i]][part].right > 0) {
                res.push(matrices[uplines[i]][part].right);
            }
        }

        return res;
    }

    function sendMatrixPayout(uint256 fromID, uint256 level)
        private
        returns (uint256)
    {
        uint256 matrixUpline = getUplineAtBlock(
            fromID,
            levelConfigurations[level].paymentGeneration
        );
        sendPayout(
            userAddresses[matrixUpline],
            amountFromDollar(levelConfigurations[level].perDropEarning)
        );
        emit MatrixPayout(
            matrixUpline,
            userID,
            levelConfigurations[level].perDropEarning
        );

        return matrixUpline;
    }

    function getUplineAtBlock(
        uint256 userID,
        uint256 part,
        uint256 block
    ) returns (uint256) {
        if (block == 1) {
            return matrices[userID][part].uplineID;
        }

        return getUplineAtBlock(userID, part, block - 1);
    }

    function moveToNextLevel(uint256 userID) private {
        uint256 newLevel = users[userID].premiumLevel + 1;
        // @dev add to matrix if change in level triggers change in part
        if (
            getPartFromLevel(newLevel) >
            getPartFromLevel(users[userID].premiumLevel)
        ) {
            addToMatrix(userID, users[userID].premiumLevel + 1);
        }
        users[userID].premiumLevel = newLevel;

        emit NewLevel(userID, newLevel);

        uint256 benefactor = sendMatrixPayout(
            userID,
            newLevel
        );

        if (levelCompleted(benefactor)) {
            moveToNextLevel(benefactor);
        }
    }

    function addToMatrix(uint256 userID, uint256 level, uint256 random) private {
        uint256 part = getPartFromLevel(level);
        uint256 matrixUpline = getMatrixPositionUplineID(uplineID, part, random);
        matrices[userID][part].registered = true;
        matrices[userID][part].uplineID = matrixUpline;
        matrices[userID][part].block = matrices[matrixUpline][part].block + 1;
        if (matrices[matrixUpline][part].left == 0) {
            matrices[matrixUpline][part].left = userID;
        } else {
            matrices[matrixUpline][part].right = userID;
        }
    }

    function levelCompleted(userID) private view returns (bool) {
        uint256 lineCount = countDownlinesInBlock(
            userID,
            users[userID].premiumLevel,
            levelConfigurations[users[userID].premiumLevel].paymentGeneration
        );

        return lineCount = levelConfigurations[users[userID].premiumLevel].numberOfPayments;
    }

    function countDownlinesInBlock(
        uint256 userID,
        uint256 level,
        uint256 block
    ) private view returns (uint256 count) {
        uint256 part = getPartFromLevel(level);
        uint256[] uplines;
        uplines.push(userID);
        for (uint256 i = 1; i <= block; i++) {
            uplines = getAllLegs(uplines, part);
        }

        for (uint256 i = 0; i < uplines.length; i++) {
            if (users[uplines[i]].premiumLevel >= level) {
                count += 1;
            }
        }
    }

    function getPartFromLevel(uint256 level) private returns (uint256) {
        if (level < 3) {
            return 1;
        }
        if (level < 6) {
            return 2;
        }
        if (level < 8) {
            return 3;
        }
        if (level < 12) {
            return 4;
        }
        if (level < 15) {
            return 5;
        }
        return 6;
    }

    function getDirectLegs(uint256 userID, uint256 level) external view returns(
        uint256 left,
        uint256 leftLevel,
        uint256 right,
        uint256 rightLevel
    ) {
        require(users[userID].premiumLevel >= level, "Invalid level");
        uint256 part = getPartFromLevel(level);

        left = matrices[userID].left;
        leftLevel = users[left].premiumLevel;

        right = matrices[userID].right;
        rightLevel = users[right].premiumLevel;
    }
}
