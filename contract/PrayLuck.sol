// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
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

contract PrayLuck is StandardToken {

    struct GoodManInfo {
        address Account;
        uint256 OnceMintPrice;
        uint256 LeftPrayLuck;
    }

    /* Public variables of the token */
    string public name;
    uint8 public decimals;
    string public symbol;
    mapping (address => uint256) public mintTimeHistory;
    mapping (address => uint256) public goodManScore;
    GoodManInfo[] public goodManArray;
    address public admin;
    uint8 public dailyMintCount = 1;
    uint256 public minBalance = 1*10**16; // 0.01ETH

    constructor(uint256 _initialAmount, string memory _tokenName, string memory _tokenSymbol) {
        balances[msg.sender] = _initialAmount;
        total = _initialAmount;
        name = _tokenName;
        decimals = 0;
        symbol = _tokenSymbol;
        admin = msg.sender;
    }

    event DailyMint(address indexed _goodMan, uint256 indexed _dailyMintCount);

    function getAndUseGoodMan() private returns(address goodMan) {
        goodMan = address(0);
        if (goodManArray.length == 0) {
            return goodMan;
        }
        while (goodManArray.length > 0) {
            if (goodManArray[goodManArray.length-1].LeftPrayLuck < dailyMintCount) {
                goodManArray.pop();
                continue;
            }
            goodManArray[goodManArray.length-1].LeftPrayLuck -= dailyMintCount;
            goodMan = goodManArray[goodManArray.length-1].Account;
            break;
        }
        return goodMan;
    }

    function getLatestGoodMan() view public returns(address goodMan, uint256 onceMintPrice, uint256 leftPrayLuck, uint256 index) {
        if (goodManArray.length > 0) {
            index = goodManArray.length - 1;
            return (goodManArray[index].Account, goodManArray[index].OnceMintPrice, goodManArray[index].LeftPrayLuck, index);
        }
        return (address(0), 0, 0, 0);
    }

    function getLatestGoodManInfoList(address userAddr) view public returns(GoodManInfo[10] memory goodManList, uint256 size) {
        uint256 index = 0;
        for (uint256 i = 0; i < goodManArray.length; i++) {
            if (userAddr == goodManArray[goodManArray.length - 1 - i].Account) {
                goodManList[index] = goodManArray[goodManArray.length - 1 - i];
                index++;
            }
            if (index >= 10) {
                return (goodManList, 10);
            }
        }
        return (goodManList, index);
    }

    function getAllLatestGoodManInfoList(uint256 page) view public returns(GoodManInfo[10] memory goodManList, uint256 size) {
        uint256 index = 0;
        for (uint256 i = page * 10; i < (page + 1) * 10 && i < goodManArray.length; i++) {
            goodManList[index] = goodManArray[i];
            index++;
        }
        return (goodManList, index);
    }

    function dailyMint() external {
        require(tx.origin.balance >= minBalance, "less bal");
        require(block.timestamp - mintTimeHistory[tx.origin] > 1 days, "minted");
        PrayLuck(address(this)).transfer(tx.origin, dailyMintCount);
        address goodMan = getAndUseGoodMan();
        if (goodMan != address(0)) {
            goodManScore[goodMan] += dailyMintCount;
        }
        mintTimeHistory[tx.origin] = block.timestamp;
        emit DailyMint(goodMan, dailyMintCount);
    }

    function beAGoodMan(uint256 onceMintPrice, uint256 prayLuckCount) payable external {
        if (prayLuckCount < dailyMintCount || msg.value < onceMintPrice * prayLuckCount || onceMintPrice == 0 || prayLuckCount == 0) {
            return;
        }
        if (goodManArray.length > 0 && onceMintPrice <= goodManArray[goodManArray.length-1].OnceMintPrice) {
            return;
        }
        PrayLuck(address(this)).transferFrom(msg.sender, address(this), prayLuckCount);
        goodManArray.push(GoodManInfo(msg.sender, onceMintPrice, prayLuckCount));
    }

    function setAdmin(address _admin) external {
        require(msg.sender == admin);
        admin = _admin;
    }

    function setDailyMintCount(uint8 _dailyMintCount) external {
        require(msg.sender == admin);
        dailyMintCount = _dailyMintCount;
    }

    function setMinClaimBalance(uint256 _minBalance) external {
        require(msg.sender == admin);
        minBalance = _minBalance;
    }

    function rescueToken(address token, uint256 value) external {
        require(token != address(this));
        require(msg.sender == admin);
        Token(token).transfer(msg.sender, value);
    }

    function rescue() external {
        require(msg.sender == admin);
        payable(msg.sender).transfer(address(this).balance);
    }
}