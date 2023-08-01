// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;
interface Token{
	function totalSupply() external returns (uint256);

	function balanceOf(address _owner) external returns (uint256 balance);

	function transfer(address _to, uint256 _value) external returns (bool success);

	function transferFrom(address _from, address _to, uint256 _value) external returns (bool success);

	function approve(address _spender, uint256 _value) external returns (bool success);

	function allowance(address _owner, address _spender) external returns (uint256 remaining);

	event Transfer(address indexed _from, address indexed _to, uint256 _value);

	event Approval(address indexed _owner, address indexed _spender, uint256 _value);
}

contract StandardToken is Token {

	uint256 total;

	function transfer(address _to, uint256 _value) external returns (bool success) {
		require(balances[msg.sender] >= _value);
		balances[msg.sender] -= _value;
		balances[_to] += _value;
		emit Transfer(msg.sender, _to, _value);
		return true;
	}


	function transferFrom(address _from, address _to, uint256 _value) external returns (bool success) {
		require(balances[_from] >= _value && allowed[_from][msg.sender] >= _value);
		balances[_to] += _value;
		balances[_from] -= _value;
		allowed[_from][msg.sender] -= _value;
		emit Transfer(_from, _to, _value);
		return true;
	}
	function balanceOf(address _owner) external view returns (uint256 balance) {
		return balances[_owner];
	}

	function approve(address _spender, uint256 _value) external returns (bool success)
	{
	    allowed[msg.sender][_spender] = _value;
		emit Approval(msg.sender, _spender, _value);
		return true;
	}

	function allowance(address _owner, address _spender) external view returns (uint256 remaining) {
	    return allowed[_owner][_spender];
	}

	function totalSupply() external view returns (uint256) {
		return total;
	}

	mapping (address => uint256) balances;
	mapping (address => mapping (address => uint256)) allowed;
}

contract PrayLuckStar is StandardToken {

    struct GodInfo {
        uint256 PrayLuckAddition;
        uint256 ActiveSeconds;
        uint256 StartTimestamp;
        uint256 GodName;
    }
	/* Public variables of the token */
    address public admin;
	string public name;
	uint8 public decimals;
	string public symbol;
    uint8 public minSpecialPrayCount = 7;
    address public prayLuckToken;
    uint16 public basePLSRate = 1000;
    uint16 public unitAdditionRate = 100;
    uint8 public unitAdditionGodMultiple = 1;
    uint32 public godSelectRandomSalt = 4;
    uint16 public maxGodUnitPriceMultiCount = 100;
    uint256 public unitJumpDragonGatePrice = 5 * 10**14;
    uint16 public starExchangeRate = 500;
    uint16 public sunnyAwardUserLuck = 5000;
    mapping (address => uint256) public godsPrayLuckCount;
    uint256 public totalGodPLCount = 0;
    mapping (address => uint16) public userPrayLuckAdditionMap;
    mapping (address => GodInfo) public godInfos;
    address[] public gods;
    mapping (address => uint256) public userLuck;
    uint256 public userCount = 0;
    mapping (uint256 => address) public userAddrIndexMap;

    uint8 public adminSunnyAwardDailyMintRate = 50;
    uint8 public adminSunnyAwardAdminRate = 20;
    uint8 public adminSunnyAwardUserRate = 30;

    uint16 public godLuckAwardRate = 50;

    mapping (address => uint256) public prayTimeHistory;
    mapping (address => uint8) public dailyFirstAdditionUser;

    mapping (uint8 => mapping (address => uint256)) specialLuckHistory;

	constructor(uint256 _initialAmount, string memory _tokenName, uint8 _decimalUnits, string memory _tokenSymbol, address _prayLuckToken) {
		balances[msg.sender] = _initialAmount;
		total = _initialAmount;
		name = _tokenName;
		decimals = _decimalUnits;
		symbol = _tokenSymbol;
        admin = msg.sender;
        prayLuckToken = _prayLuckToken;
	}

	event Random(uint256 indexed _random);
	event RandomSpecial(uint256 indexed _lotteryRandom, uint256 indexed _win, address indexed _god);

    function calculateRandom() private returns(uint256 random) {
        return uint256(keccak256(abi.encodePacked(block.timestamp + block.difficulty + uint256(keccak256(abi.encodePacked(block.coinbase))) / block.timestamp + block.gaslimit + uint256(keccak256(abi.encodePacked(msg.sender))) / block.timestamp + block.number + address(block.coinbase).balance + Token(prayLuckToken).balanceOf(address(this)))));
    }

    function lottery(uint256 lotteryRandom) private view returns(bool result) {
        return basePLSRate + userLuck[msg.sender] / 10000 * unitAdditionRate >= 100000 - lotteryRandom;
    }

    function mintPrayLuckStar(address to, uint256 count) private {
        balances[to] += count;
        total += count;
        emit Transfer(address(0), to, count);
    }

    function selectGod(uint256 randomNum) private returns(address god, uint256 addition) {
        bool found = false;
        while(gods.length > 0) {
            uint256 randomGod = randomNum % (gods.length + godSelectRandomSalt);
            if (randomGod >= gods.length) {
                break;
            }
            god = gods[randomGod];
            if (godInfos[god].StartTimestamp + godInfos[god].ActiveSeconds < block.timestamp) {
                gods[randomGod] = gods[gods.length - 1];
                gods.pop();
                godInfos[god].PrayLuckAddition = 0;
                continue;
            }
            found = true;
            break;
        }
        if (found) {
            return (god, godInfos[god].PrayLuckAddition);
        }
        return (address(0), 0);
    }

    function getUserLuckAndAddIntoMap() private returns(uint256 luckCount) {
        luckCount = userLuck[msg.sender];
        if (luckCount == 0) {
            userAddrIndexMap[userCount] = msg.sender;
            userCount++;
        }
        return luckCount;
    }

    function randomSendPLToUser(uint256 randomNum, uint256 sunnyUserCount, uint256 plCount) private {
        for (uint256 i = 0; i < sunnyUserCount; i++) {
            uint256 userIndex = (randomNum + i * block.timestamp) % userCount;
            address userAddr = userAddrIndexMap[userIndex];
            Token(prayLuckToken).transfer(userAddr, plCount);
        }
    }

    function recordSpecialGoodLuck(uint256 lotteryRandom) private {
        if (lotteryRandom >= 99990) {
            specialLuckHistory[0][msg.sender] += 1;
        } else if (lotteryRandom >= 99900) {
            specialLuckHistory[1][msg.sender] += 1;
        } else if (lotteryRandom >= 99000) {
            specialLuckHistory[2][msg.sender] += 1;
        }
    }

    function recordSpecialBadLuck() private {
        uint256 luck = userLuck[msg.sender] * unitAdditionRate;
        if (luck >= 950000000) {
            specialLuckHistory[3][msg.sender] += 1;
        } else if (luck >= 900000000) {
            specialLuckHistory[4][msg.sender] += 1;
        } else if (luck >= 850000000) {
            specialLuckHistory[5][msg.sender] += 1;
        }
    }

    function prayLuckSimple() external {
        Token(prayLuckToken).transferFrom(msg.sender, address(this), 1);
        uint256 luckHistory = getUserLuckAndAddIntoMap();
        uint256 currentLuck = 10000;
        if (dailyFirstAdditionUser[msg.sender] > 0 && block.timestamp - prayTimeHistory[msg.sender] > 1 days) {
            currentLuck += 10000 * dailyFirstAdditionUser[msg.sender];
            prayTimeHistory[msg.sender] = block.timestamp;
        }
        userLuck[msg.sender] = luckHistory + currentLuck;
        emit Random(calculateRandom() % 100000);
    }
    function prayLuckSpecial(uint256 plCount) external {
        require(plCount >= minSpecialPrayCount);
        Token(prayLuckToken).transferFrom(msg.sender, address(this), plCount);

        uint256 randomNum = calculateRandom();
        (address god, uint256 addition) = selectGod(randomNum);

        uint256 luck = plCount * (10000 + randomNum % 10000 * (10000 + userPrayLuckAdditionMap[msg.sender] + addition) / 10000);
        uint256 luckHistory = getUserLuckAndAddIntoMap();
        userLuck[msg.sender] = luckHistory + luck;

        if (god != address(0)) {
            godsPrayLuckCount[god] += plCount;
            totalGodPLCount += plCount;
            userLuck[god] += luck * godLuckAwardRate / 100;
        }

        uint256 lotteryRandom = randomNum % 100000;
        if (lottery(lotteryRandom)) {
            mintPrayLuckStar(msg.sender, 1);
            userLuck[msg.sender] = 1;
            recordSpecialGoodLuck(lotteryRandom);
            emit RandomSpecial(lotteryRandom, 1, god);
        } else {
            recordSpecialBadLuck();
            emit RandomSpecial(lotteryRandom, 0, god);
        }
    }

    function jumpDragonGate(uint256 unitPrice) payable external {
        if (msg.value < unitPrice || unitPrice < unitJumpDragonGatePrice) {
            return;
        }
        uint256 activeDays = msg.value / unitPrice;
        if (activeDays == 0) {
            return;
        }
        if (godInfos[msg.sender].PrayLuckAddition == 0) {
            gods.push(msg.sender);
        }
        uint256 multiple = unitPrice / unitJumpDragonGatePrice;
        if (multiple > 100) {
            multiple = 100;
        }
        godInfos[msg.sender] = GodInfo(multiple * unitAdditionRate * unitAdditionGodMultiple, activeDays*86400, block.timestamp, calculateRandom() % 10000);
    }

    function exchange(uint256 plCount) external {
        require(plCount > 0 && plCount <= godsPrayLuckCount[msg.sender] && plCount >= starExchangeRate);
        uint256 starCount = plCount / starExchangeRate;
        uint256 costPLCount = starCount * starExchangeRate;
        godsPrayLuckCount[msg.sender] -= costPLCount;
        totalGodPLCount -= costPLCount;
        mintPrayLuckStar(msg.sender, starCount);
    }

    function sunnyAward(uint256 sunnyUserCount, uint256 plCount) external {
        require(sunnyUserCount > 0 && plCount > 0 && plCount * sunnyUserCount <= godsPrayLuckCount[msg.sender]);
        uint256 randomNum = calculateRandom();
        uint256 costPLCount = plCount * sunnyUserCount;
        godsPrayLuckCount[msg.sender] -= costPLCount;
        totalGodPLCount -= costPLCount;
        userLuck[msg.sender] += sunnyUserCount * sunnyAwardUserLuck + costPLCount * (10000 + randomNum % 10000) + (plCount - 1) * sunnyUserCount * randomNum % 10000;
        randomSendPLToUser(randomNum, sunnyUserCount, plCount);
    }

    function adminSunnyAward(uint256 sunnyUserCount) external {
        require(msg.sender == admin);
        uint256 plBalance = Token(prayLuckToken).balanceOf(address(this));
        require(plBalance > totalGodPLCount);
        uint256 adminPLCount = plBalance - totalGodPLCount;
        uint256 userAward = adminPLCount * adminSunnyAwardUserRate / 100 / sunnyUserCount;
        require(userAward > 0, "lesspl");
        uint256 admintAward = adminPLCount * adminSunnyAwardAdminRate / 100;
        uint256 dailyMintAward = adminPLCount * adminSunnyAwardDailyMintRate / 100;

        Token(prayLuckToken).transfer(prayLuckToken, dailyMintAward);
        Token(prayLuckToken).transfer(admin, admintAward);

        randomSendPLToUser(calculateRandom(), sunnyUserCount, userAward);
    }

	function rescueToken(address token, uint256 value) external {
        require(token != prayLuckToken);
        require(msg.sender == admin);
        Token(token).transfer(msg.sender, value);
	}

	function rescue() external {
        require(msg.sender == admin);
        payable(msg.sender).transfer(address(this).balance);
	}

    function setAdmin(address _admin) external {
        require(msg.sender == admin);
        admin = _admin;
    }

    function setMinSpecialPrayCount(uint8 _minSpecialPrayCount) external {
        require(msg.sender == admin);
        minSpecialPrayCount = _minSpecialPrayCount;
    }

    function setUserPrayLuckAddition(address user, uint16 addition) external {
        require(msg.sender == admin);
        require(addition <= 60000);
        userPrayLuckAdditionMap[user] = addition;
    }

    function setBasePLSRate(uint16 _basePLSRate) external {
        require(msg.sender == admin);
        require(_basePLSRate <= 6000);
        basePLSRate = _basePLSRate;
    }

    function setUnitAdditionRate(uint16 _unitAdditionRate) external {
        require(msg.sender == admin);
        require(_unitAdditionRate <= 6000);
        unitAdditionRate = _unitAdditionRate;
    }

    function setUnitJumpDragonGatePrice(uint256 _unitJumpDragonGatePrice) external {
        require(msg.sender == admin);
        require(_unitJumpDragonGatePrice <= 1000**18);
        unitJumpDragonGatePrice = _unitJumpDragonGatePrice;
    }

    function setUnitAdditionGodMultiple(uint8 _unitAdditionGodMultiple) external {
        require(msg.sender == admin);
        require(_unitAdditionGodMultiple <= 200);
        unitAdditionGodMultiple = _unitAdditionGodMultiple;
    }

    function setStarExchangeRate(uint16 _starExchangeRate) external {
        require(msg.sender == admin);
        require(_starExchangeRate <= 50000);
        require(_starExchangeRate >= 10);
        starExchangeRate = _starExchangeRate;
    }

    function setAdminSunnyAwardConfig(uint8 _adminSunnyAwardDailyMintRate, uint8 _adminSunnyAwardAdminRate, uint8 _adminSunnyAwardUserRate) external {
        require(msg.sender == admin);
        require(_adminSunnyAwardDailyMintRate + _adminSunnyAwardAdminRate + _adminSunnyAwardUserRate == 100);
        adminSunnyAwardDailyMintRate = _adminSunnyAwardDailyMintRate;
        adminSunnyAwardAdminRate = _adminSunnyAwardAdminRate;
        adminSunnyAwardUserRate = _adminSunnyAwardUserRate;
    }

    function setGodLuckAwardRate(uint16 _godLuckAwardRate) external {
        require(msg.sender == admin);
        require(_godLuckAwardRate <= 1000);
        godLuckAwardRate = _godLuckAwardRate;
    }

    function setSunnyAwardUserLuck(uint16 _sunnyAwardUserLuck) external {
        require(msg.sender == admin);
        require(_sunnyAwardUserLuck <= 60000);
        sunnyAwardUserLuck = _sunnyAwardUserLuck;
    }

    function setDailyFirstAdditionUser(address user, uint8 addition) external {
        require(msg.sender == admin);
        require(addition <= 100);
        dailyFirstAdditionUser[user] = addition;
    }

    function setGodSelectRandomSalt(uint32 _godSelectRandomSalt) external {
        require(msg.sender == admin);
        godSelectRandomSalt = _godSelectRandomSalt;
    }

    function setMaxGodUnitPriceMultiCount(uint16 _maxGodUnitPriceMultiCount) external {
        require(msg.sender == admin);
        maxGodUnitPriceMultiCount = _maxGodUnitPriceMultiCount;
    }

}