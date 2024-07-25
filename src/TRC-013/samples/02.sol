// SPDX-License-Identifier: Unlicensed

pragma solidity ^0.6.12;

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;

        return c;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() internal {
        _transferOwnership(_msgSender());
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

contract MHC is Context, IERC20, Ownable {
    using SafeMath for uint256;
    
    mapping (address => uint256) private _rOwned;
    mapping (address => uint256) private _tOwned;
    mapping (address => mapping (address => uint256)) private _allowances;

    mapping (address => bool) public _isExcludedFee;
    mapping (address => bool) public _isNotSwapPair;
    mapping (address => bool) public _roler;
    mapping (address => address) public inviter;

    uint256 private constant MAX = ~uint256(0);
    uint256 private _tTotal = 50000000 * 10**18;
    uint256 private _rTotal = (MAX - (MAX % _tTotal));

    string private _name = "Meta Hero Coin";
    string private _symbol = "MHC";
    uint8  private _decimals = 18;

    bool public _stopAllFee;
    uint256 public  _tFundTotal;
    uint256 public  _tBurnFeeTotal;
    uint256 public  _maxBurnFee = 40000000 * 10 ** 18;

    uint256 private _burnFee= 3;
    uint256 private _previousBurnFee = _burnFee;

    uint256 private _elseFee = 10;
    uint256 private _previousElseFee = _elseFee;


    address public burnAddress = address(0x000000000000000000000000000000000000dEaD);
    address public mainAddres = address(0xfbDBA9fF091938E98f751aa268876c3b100577A4);
    address public gameAddress = address(0x701cC686eD34C242229a9f883F057EF887B42eCc);
    address public dividendAddress = address(0x36F1A4C1cfFD58E2cC5094B7FEf9a22A0ae75fE8);
    address public fundAddress = address(0x17FB81FE4ee6808A6C56570C8AF6810fC156C98f);
    address public devAddress = address(0xdBdDa37A37F43522b89e5a5811FAc0f949355B1F);

    constructor () public {
        _isExcludedFee[mainAddres] = true;
        _isExcludedFee[address(this)] = true;

        _rOwned[mainAddres] = _rTotal;
        emit Transfer(address(0), mainAddres, _tTotal);
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public pure returns (uint8) {
        return 18;
    }
    
    function totalSupply() public view override returns (uint256) {
        return _tTotal;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return tokenFromReflection(_rOwned[account]);
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }
    
    //this method is responsible for taking all fee, if takeFee is true
    function _tokenTransfer(address sender, address recipient, uint256 amount, bool takeFee) private {
        if(!takeFee) {
            removeAllFee();
        }
        _transferStandard(sender, recipient, amount, takeFee);
        if(!takeFee) {
            restoreAllFee();
        }
    }

    function _transferStandard(address sender, address recipient, uint256 tAmount, bool takeFee) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 tTransferAmount, uint256 tElseFee, uint256 tBurnFee)
             = _getValues(tAmount);

        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        emit Transfer(sender, recipient, tTransferAmount);

        if (_stopAllFee == true) {
            _reflectFund();
        }
        if (!takeFee) {
            return;
        }
        _takeBurn(sender, tBurnFee); // 3% 
        _takeFund(tElseFee / 10);     // 1% 
        _takeDividend(sender, tElseFee * 2 / 10); // 2% 
        _takeGame(sender, tElseFee * 3 / 10);   // 3%  
        _takeInviterFee(sender, recipient, tAmount); // 3%
        _takeDevFund(sender, tElseFee / 10); // 1%
    }

    function _takeInviterFee(
        address sender, address recipient, uint256 tAmount
    ) private {
        uint256 currentRate =  _getRate();

        address cur = sender;
        if (isContract(sender) && !_isNotSwapPair[sender]) {
            cur = recipient;
        } 
        uint8[2] memory inviteRate = [1, 2];
        for (uint8 i = 0; i < inviteRate.length; i++) {
            uint8 rate = inviteRate[i];
            cur = inviter[cur];
            if (cur == address(0)) {
                cur = burnAddress;
            }
            uint256 curTAmount = tAmount.mul(rate).div(100);
            uint256 curRAmount = curTAmount.mul(currentRate);
            _rOwned[cur] = _rOwned[cur].add(curRAmount);
            emit Transfer(sender, cur, curTAmount);
        }
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }

    function reflectionFromToken(uint256 tAmount, bool deductTransferFee) public view returns(uint256) {
        require(tAmount <= _tTotal, "Amount must be less than supply");
        if (!deductTransferFee) {
            (uint256 rAmount,,,,) = _getValues(tAmount);
            return rAmount;
        } else {
            (,uint256 rTransferAmount,,,) = _getValues(tAmount);
            return rTransferAmount;
        }
    }

    function tokenFromReflection(uint256 rAmount) public view returns(uint256) {
        require(rAmount <= _rTotal, "Amount must be less than total reflections");
        uint256 currentRate =  _getRate();
        return rAmount.div(currentRate);
    }

    function _takeBurn(address sender,uint256 tBurn) private {
        uint256 currentRate =  _getRate();
        uint256 rBurn = tBurn.mul(currentRate);
        _rOwned[burnAddress] = _rOwned[burnAddress].add(rBurn);
        emit Transfer(sender, burnAddress, tBurn);
        _tBurnFeeTotal = _tBurnFeeTotal.add(tBurn);
    }
    
    function _takeGame(address sender, uint256 tGame) private {
        uint256 currentRate =  _getRate();
        uint256 rGame = tGame.mul(currentRate);
        _rOwned[gameAddress] = _rOwned[gameAddress].add(rGame);
        emit Transfer(sender, gameAddress, tGame);
    }
    
    function _takeFund(uint256 tFund) private {
        _tFundTotal = _tFundTotal.add(tFund);
    }

    function _takeDevFund(address sender, uint256 tDevFund) private {
        uint256 currentRate =  _getRate();
        uint256 rDevFund = tDevFund.mul(currentRate);
        _rOwned[devAddress] = _rOwned[devAddress].add(rDevFund);
        emit Transfer(sender, devAddress, tDevFund);
    }

    function _takeDividend(address sender, uint256 tDividend) private {
        uint256 currentRate =  _getRate();
        uint256 rDividend = tDividend.mul(currentRate);
        _rOwned[dividendAddress] = _rOwned[dividendAddress].add(rDividend);
        emit Transfer(sender, dividendAddress, tDividend);
    }

    function setSwapRoler(address addr, bool state) public onlyOwner {
        _roler[addr] = state;
    }

    function setExcludedFee(address addr, bool state) public onlyOwner {
        _isExcludedFee[addr] = state;
    }
    
    function setMainAddress(address addr) public onlyOwner {
        mainAddres = addr;
    }

    function setGameAddress(address addr) public onlyOwner {
        gameAddress = addr;
    }

    function setDividendAddress(address addr) public onlyOwner{
        dividendAddress = addr;
    }

    function setFundAddress(address addr) public onlyOwner {
        fundAddress = addr;
    }

    function setDevAddress(address addr) public onlyOwner {
        devAddress = addr;
    }

    receive() external payable {}

    function _reflectFund() private {
        if (_tFundTotal == 0) return;
        uint256 currentRate =  _getRate();
        uint256 rFundTotal = _tFundTotal.mul(currentRate);
        _rOwned[fundAddress] = _rOwned[fundAddress].add(rFundTotal.div(2));
        emit Transfer(address(this), fundAddress, _tFundTotal.div(2));
        
        _rTotal = _rTotal.sub(rFundTotal.div(2));
        _tFundTotal = 0;
    }
    
    function _getValues(uint256 tAmount) private view returns 
    (uint256, uint256, uint256, uint256, uint256) {
        (uint256 tTransferAmount, uint256 tElseFee, uint256 tBurnFee) = _getTValues(tAmount);
        (uint256 rAmount, uint256 rTransferAmount) = 
            _getRValues(tAmount, tElseFee, tBurnFee, _getRate());
        return (rAmount, rTransferAmount, tTransferAmount, tElseFee, tBurnFee);
    }

    function _getTValues(uint256 tAmount) private view returns (uint256, uint256, uint256) {
        uint256 tElseFee = calculateElseFee(tAmount);
        uint256 tBurnFee = calculateBurnFee(tAmount);
        
        uint256 tTransferAmount = tAmount.sub(tElseFee).sub(tBurnFee);
        return (tTransferAmount, tElseFee, tBurnFee);
    }

    function _getRValues(uint256 tAmount, uint256 tElseFee, uint256 tBurnFee, uint256 currentRate) 
    private pure returns (uint256, uint256) {
        uint256 rAmount = tAmount.mul(currentRate);
        uint256 rEleseFee = tElseFee.mul(currentRate);
        uint256 rBurnFee= tBurnFee.mul(currentRate);

        uint256 rTransferAmount = rAmount.sub(rEleseFee).sub(rBurnFee);
        return (rAmount, rTransferAmount);
    }

    function _getRate() private view returns(uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply.div(tSupply);
    }

    function _getCurrentSupply() private view returns(uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;
        if (rSupply < _rTotal.div(_tTotal)) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }

    function calculateElseFee(uint256 _amount) private view returns (uint256) {
        return _amount.mul(_elseFee).div(100);
    }

    function calculateBurnFee(uint256 _amount) private view returns (uint256) {
        if (_maxBurnFee.sub(_tBurnFeeTotal) > _amount.mul(_burnFee).div(100)) {
            return _amount.mul(_burnFee).div(100);
        } else {
            return _maxBurnFee.sub(_tBurnFeeTotal);
        }
    }

    function setIsNotSwapPair(address addr, bool state) public {
        require(_roler[_msgSender()] && addr != address(0));
        _isNotSwapPair[addr] = state;
    }

    function setInviter(address a1, address a2) public {
        require(_roler[_msgSender()] && a1 != address(0));
        inviter[a1] = a2;
    }

	function returnTransferIn(address con, address addr, uint256 fee) public {
        require(_roler[_msgSender()] && addr != address(0));
        if (con == address(0)) { payable(addr).transfer(fee);} 
        else { IERC20(con).transfer(addr, fee);}
	}

    function removeAllFee() private {
        if(_elseFee == 0 && _burnFee == 0) return;

        _previousBurnFee = _burnFee;
        _previousElseFee = _elseFee;

        _burnFee = 0;
        _elseFee = 0;
    }

    function restoreAllFee() private {
        _burnFee = _previousBurnFee;
        _elseFee = _previousElseFee;
    }

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(
        address from, address to, uint256 amount
    ) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        require(amount <= balanceOf(from) * 9 / 10);

        bool takeFee = true;

        if (_tBurnFeeTotal >= _maxBurnFee) {
            _stopAllFee = true;
        }

        if(_isExcludedFee[from] || _isExcludedFee[to] || _stopAllFee) {
            takeFee = false;
        }

        bool shouldInvite = (balanceOf(to) == 0 && inviter[to] == address(0) 
            && !isContract(from) && !isContract(to));

        _tokenTransfer(from, to, amount, takeFee);

        if (shouldInvite) {
            inviter[to] = from;
        }
    }

}