// SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;

import "./POG20.sol";
import "./RecordCreation.sol";

contract PogDefi is POG20, RecordCreation {
    using SafeMath for uint256;
    
    constructor() POG20(2000000) {
        _name = "Pog Defi";
        _symbol = "POG";
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;

import "./PogStaking.sol";
import "./PogBotController.sol";
import '@openzeppelin/contracts/math/SafeMath.sol';

abstract contract POG20 is PogStaking, PogBotController {
    using SafeMath for uint256;

    address private devAddress = 0x5D8123214B05c7198eFB524616BCF2831a3eaDE7;
    bool private _firstTx = true; // flag for first tx (as this will be to provide liquidity so don't want limit)
    uint256 private _burnRate = 15; // 0.15% of tx to be burned
    uint256 private _devRate = 15; // 0.15% of tx to be given to dev address
    uint256 private _distributeRatio = 18; // 1:18 ratio of burn:distribute
    uint256 private _totalBurnt;
    uint32 private _maxTxPercent = 250; // max size as % of supply as percentage to 1d.p, eg 50 = 5.0%

    /**
     * Mint tx sender with initial supply
     */
    constructor(uint256 supply) {
        uint256 amount = supply * uint256(10 ** _decimals);
        _balances[_msgSender()] = _balances[_msgSender()].add(amount);
        _totalSupply = _totalSupply.add(amount);
        updateHoldersTransferRecipient(_msgSender()); // ensure receiver is set as sender
        emit Transfer(address(0), _msgSender(), amount);
    }
    
    function getOwner() external view override returns (address) {
        return owner();
    }

    function getTotalBurnt() external view returns (uint256) {
        return _totalBurnt;
    }
    
    function getBurnRate() public view returns (uint256) {
        return _burnRate;
    }

    function getDevRate() public view returns (uint256) {
        return _devRate;
    }

     function getDistributionRatio() public view returns (uint256) {
         return _distributeRatio;
     }
    
    function setBurnRate(uint256 newRate) external onlyOwner {
        require(newRate < 100);
        _burnRate = newRate;
    }

    function setDevRate(uint256 newRate) external onlyOwner {
        require(newRate < 100);
        _devRate = newRate;
    }
    
    function setDistributionRatio(uint256 newRatio) external onlyOwner {
        require(newRatio >= 1);
        _distributeRatio = newRatio;
    }

        /**
     * Burns transaction amount as per burn rate & returns remaining transfer amount. 
     */
    function _txBurn(address account, uint256 txAmount, bool isDevRecipient) internal returns (uint256) {
        if (isDevRecipient) {
            return txAmount;
        }
        uint256 toBurn = txAmount.mul(_burnRate).div(10000);
        uint256 toDistribute = toBurn.mul(_distributeRatio);
        uint256 toDev = txAmount.mul(_devRate).div(10000);
        
        _distribute(account, toDistribute);
        _burn(account, toBurn);
        _transferFrom(account, devAddress, toDev);
        
        return txAmount.sub(toBurn).sub(toDistribute).sub(toDev);
    }
    
    /**
     * Burn amount tokens from sender
     */
    function burn(uint256 amount) public {
        require(_balances[_msgSender()] >= amount);
        _burn(_msgSender(), amount);
    }
    
    /**
     * Burns amount of tokens from account
     */
    function _burn(address account, uint256 amount) internal {
        require(account != address(0), 'BEP20: burn from the zero address');
        if(amount == 0){ return; }
        
        _totalSupply = _totalSupply.sub(amount);
        _totalBurnt = _totalBurnt.add(amount);
        _balances[account] = _balances[account].sub(amount);
        
        emit Transfer(account, address(0), amount);
    }
    
    /**
     * Ensure tx size is within allowed % of supply
     */
    function checkTxAmount(uint256 amount) internal {
        if(_firstTx) {
            _firstTx = amount == 0 ? true : false;
            return;
        } // skip first tx as this will be providing 100% as liquidity
        require(amount <= _totalSupply.mul(_maxTxPercent).div(1000), "Tx size exceeds limit");
    }
    
    /**
     * Change the max tx size percent. Required to be from 1% to 100%
     */
    function setMaxTxPercent(uint32 amount) external onlyOwner {
        require(amount > 10 && amount < 1000, "Invalid max tx size");
        _maxTxPercent = amount;
    }
    
    function _transferFrom(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "Can't transfer from zero");
        require(recipient != address(0), "Can't transfer to zero");
        
        // ensure tx size is below limit
        checkTxAmount(amount); 

        require(_balances[sender] >= amount, "Not enough balance");

        bool isDevRecipient = recipient == devAddress;
        
        // require allowance if sender is not transaction creator
        if(!isDevRecipient && sender != _msgSender()) {
            _allowances[sender][_msgSender()] = _allowances[sender][_msgSender()].sub(amount, "Not enough allowance");
        }
        // burn & distribute
        uint256 sendAmt = _txBurn(sender, amount, isDevRecipient);
        
        // transfer
        _balances[sender] = _balances[sender].sub(sendAmt);
        _balances[recipient] = _balances[recipient].add(sendAmt);
        
        // update holders
        updateHoldersTransferSender(sender);
        updateHoldersTransferRecipient(recipient);
        
        // call any hooks
        callAllPogBots(sender, recipient, amount);
        
        emit Transfer(sender, recipient, sendAmt);
    }
    

    function _approve (address owner, address spender, uint256 amount) internal {
        require(owner != address(0), 'BEP20: approve from the zero address');
        require(spender != address(0), 'BEP20: approve to the zero address');

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
    
    function approve(address spender, uint256 amount) external override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }
    
    function transfer(address recipient, uint256 amount) external override returns (bool) {
         _transferFrom(_msgSender(), recipient, amount);
         return true;
     }

    function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool) {
        _transferFrom(sender, recipient, amount);
        return true;
    }
    
    /**
     * Bulk execute transfers
     */
    function multiTransfer(address[] memory accounts, uint256[] memory amounts) external {
        require(accounts.length == amounts.length, "Accounts & amounts must be same length");
        for(uint256 i=0; i<accounts.length; i++){
            _transferFrom(_msgSender(), accounts[i], amounts[i]);
        }
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {BEP20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {BEP20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, 'BEP20: decreased allowance below zero'));
        return true;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;

abstract contract RecordCreation {
    uint256 public creationBlock;
    uint256 public creationTimestamp;
    
    constructor(){
        creationBlock = block.number;
        creationTimestamp = block.timestamp;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;

import "./lib/IBEP20.sol";
import "./lib/BEP20.sol";
import "./lib/IPogStaking.sol";
import "./lib/SafeBEP20.sol";
import "./HolderController.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract PogStaking is IPogStaking, BEP20, HolderController, Ownable {
    using SafeBEP20 for IBEP20;
    using SafeMath for uint256;

    /**
     * Struct for holding record of account stakes.
     */
    struct Stake {
        uint256 LP; // Amount of LP tokens staked
        uint256 excludedAmt; // Amount of staking rewards to exclude from returns (if claimed or staked after)
        uint256 realised; // realised rewards
    }

    mapping (address => Stake) _stakes;
    
    IBEP20 private _pair;
    bool private _pairInitialized;
    uint256 private _totalFees;
    uint256 private _totalLP;
    uint256 private _totalRealised;

    /**
     * Require pair address to be set
     */
    modifier pairInitialized() {
        require(_pairInitialized);
        _;
    }
    
    function getTotalStaked() external override view returns (uint256) {
        return _totalLP;
    }
    
    function getTotalFees() external override view returns (uint256) {
        return _totalFees;
    }
    
    function getStake(address account) public override view returns (uint256) {
        return _stakes[account].LP;
    }
    
    function getEarnings(address staker) external override view returns (uint256) {
        return _stakes[staker].realised; // realised gains
    }
    
    function getUnrealisedEarnings(address staker) external view returns (uint256) {
        return earnt(staker);
    }
    
    function stake(uint256 amount) external override pairInitialized {
        _stake(msg.sender, amount);
    }
    
    function unstake(uint256 amount) external override pairInitialized {
        _unstake(msg.sender, amount);
    }
    
    /**
     * Return Cake-LP pair address
     */
    function getPairAddress() external view override returns (address) {
        return address(_pair);
    }
    
    function forceUnstakeAll() external override onlyOwner {
        for(uint256 i=0; i<_holders.length; i++){
            uint256 amt = getStake(_holders[i]);
            if(amt > 0){
                _unstake(_holders[i], amt); 
            }
        }
    }
    
    function balanceOf(address account) public view override returns (uint256) {
        //Add outstanding staking rewards to balance
        return _balances[account];
    }
    
    /**
     * Convert unrealised staking gains into actual balance
     */
    function realise() public {
        _realise(msg.sender);
    }
    
    function _realise(address account) internal {
        if (getStake(account) != 0){
            uint256 amount = earnt(account);
            _balances[account] = _balances[account].add(amount);
            _stakes[account].realised = _stakes[account].realised.add(amount);
            _totalRealised = _totalRealised.add(amount);
        }
        _stakes[account].excludedAmt = _totalFees;
    }
    
    /**
     * Calculate current outstanding staking gains
     */
    function earnt(address account) internal view returns (uint256) {
        if (_stakes[account].excludedAmt == _totalFees || _stakes[account].LP == 0) {
            return 0;
        }
        uint256 availableFees = _totalFees.sub(_stakes[account].excludedAmt);
        uint256 share = availableFees.mul(_stakes[account].LP).div(_totalLP); // won't overflow as even totalsupply^2 is less than uint256 max
        return share;
    }
    
    /**
     * Stake amount LP from account
     */
    function _stake(address account, uint256 amount) internal {
        _pair.safeTransferFrom(account, address(this), amount);
        
        // realise staking gains now (also works to set excluded amt to current total rewards)
        _realise(account); 
        
        // add to current address' stake
        _stakes[account].LP = _stakes[account].LP.add(amount);
        _totalLP = _totalLP.add(amount);
        
        // ensure staker is recorded as holder
        updateHoldersStaked(account);
        
        emit Staked(account, amount);
    }
    
    /**
     * Unstake amount for account
     */
    function _unstake(address account, uint256 amount) internal {
        require(_stakes[account].LP >= amount);
        
        _realise(account);
        
        // remove stake
        _stakes[account].LP = _stakes[account].LP.sub(amount);
        _totalLP = _totalLP.sub(amount);
        
        // send LP tokens back
        _pair.safeTransfer(account, amount);
        
        // check if sender is no longer a holder
        updateHoldersUnstaked(account);
        
        emit Unstaked(account, amount);
    }
    
    /**
     * Distribute amount to stakers.
     */
    function distribute(uint256 amount) external {
        _realise(msg.sender);
        require(_balances[msg.sender] >= amount);
        
        _balances[msg.sender] = _balances[msg.sender].sub(amount);
        _distribute(msg.sender, amount);
    }
    
    /**
     * Distribute amount from account as transaction fee
     */
    function _distribute(address account, uint256 amount) internal {
        _totalFees = _totalFees.add(amount);
        emit FeesDistributed(account, amount);
    }
    
    /**
     * Check if account is holding in context of transaction sender
     */
    function updateHoldersTransferSender(address account) internal {
        if( !isStillHolding(account)) {
            removeHolder(account); 
        }
    }
    
    /**
     * Check if account is still holding in context of transaction recipient
     */
    function updateHoldersTransferRecipient(address account) internal {
        if (!isHolder(account)) {
            addHolder(account);
        }
    }
    
    /**
     * Check if account is holding in context of staking tokens
     */
    function updateHoldersStaked(address account) internal {
        if (!isHolder(account)) {
            addHolder(account);
        }
    }
    
    /**
     * Check if account is still holding in context of unstaking tokens
     */
    function updateHoldersUnstaked(address account) internal {
        if (!isStillHolding(account)) {
            removeHolder(account);
        }
    }
    
    /**
     * Check if account has a balance or a stake
     */
    function isStillHolding(address account) internal view returns (bool) {
        return balanceOf(account) > 0 || getStake(account) > 0;
    }
    
    /**
     * Set the pair address.
     * Don't allow changing whilst LP is staked (as this would prevent stakers getting their LP back)
     */
    function setPairAddress(address pair) external onlyOwner {
        require(_totalLP == 0, "Cannot change pair whilst there is LP staked");
        _pair = IBEP20(pair);
        _pairInitialized = true;
    }
}


// SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;

import "./lib/IPogBot.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract PogBotController is Ownable {
    struct PogBotInfo {
        bool bot;
        uint256 adrIndex;
    }
    
    mapping (address => PogBotInfo) internal _botsInfo;
    address[] internal _pogbot;
    uint256 internal _pogbotCount;
    
    function getBots() public view returns (address[] memory) {
        return _pogbot;
    }
    
    function getBotCount() public view returns (uint256) {
        return _pogbotCount;
    }
    
    function isBot(address account) public view returns (bool) {
        return _botsInfo[account].bot;
    }
    
    function addPogBot(address bot) external onlyOwner {
        require(isContract(bot));
        _botsInfo[bot].bot = true;
        _botsInfo[bot].adrIndex = _pogbot.length;
        _pogbot.push(bot);
        _pogbotCount++;
    }
    
    function removePogBot(address bot) external onlyOwner {
        require(isBot(bot));
        _botsInfo[bot].bot = false;
        _pogbotCount--; 
        
        uint256 i = _botsInfo[bot].adrIndex;
        _pogbot[i] = _pogbot[_pogbot.length-1];
        _botsInfo[_pogbot[i]].adrIndex = i;
        _pogbot.pop();
    }
    
    function callAllPogBots(address sender, address receiver, uint256 amount) internal {
        if(getBotCount() == 0){ return; }
        for(uint256 i=0; i<_pogbot.length; i++){ 
            /* 
             * Using try-catch ensures that any errors / fails in one of the pogbot contracts will not cancel the overall transaction
             */
            try IPogBot(_pogbot[i]).callHook(msg.sender, sender, receiver, amount) {} catch {}
        }
    }
    
    /**
     * Check if address is contract.
     * Credit to OpenZeppelin
     */
    function isContract(address addr) internal view returns (bool) {
        bytes32 accountHash = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;
    
        bytes32 codehash;
        assembly {
            codehash := extcodehash(addr)
        }
        return (codehash != 0x0 && codehash != accountHash);
    }
}


// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        uint256 c = a + b;
        if (c < a) return (false, 0);
        return (true, c);
    }

    /**
     * @dev Returns the substraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b > a) return (false, 0);
        return (true, a - b);
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) return (true, 0);
        uint256 c = a * b;
        if (c / a != b) return (false, 0);
        return (true, c);
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b == 0) return (false, 0);
        return (true, a / b);
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b == 0) return (false, 0);
        return (true, a % b);
    }

    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        return a - b;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) return 0;
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: modulo by zero");
        return a % b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {trySub}.
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        return a - b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryDiv}.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting with custom message when dividing by zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryMod}.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        return a % b;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;

interface IBEP20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the token decimals.
     */
    function decimals() external view returns (uint8);

    /**
     * @dev Returns the token symbol.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the token name.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the bep token owner.
     */
    function getOwner() external view returns (address);

    /**
     * @dev Returns the amount of tokens onlyOwner by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address _owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}


// SPDX-License-Identifier: MIT

pragma solidity ^0.7.4;

import './IBEP20.sol';

import '@openzeppelin/contracts/math/SafeMath.sol';

abstract contract BEP20 is IBEP20 {
    using SafeMath for uint256;

    mapping (address => uint256) internal _balances;
    mapping (address => mapping (address => uint256)) internal _allowances;

    string internal _name;
    string internal _symbol;
    uint256 internal _totalSupply = 0;
    uint8 internal _decimals = 18;

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }
    
    function name() public view override returns (string memory) {
        return _name;
    }
    
    function symbol() public view override returns (string memory) {
        return _symbol;
    }
    
    function decimals() public view override returns (uint8) {
        return _decimals;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;

interface IPogStaking {

    function forceUnstakeAll() external;
    function getEarnings(address staker) external view returns (uint256);
    function getPairAddress() external view returns (address);
    function getStake(address staker) external view returns (uint256);
    function getTotalFees() external view returns (uint256);
    function getTotalStaked() external view returns (uint256);
    function stake(uint256 amount) external;
    function unstake(uint256 amount) external;
    
    event FeesDistributed(address account, uint256 amount);
    event Staked(address account, uint256 amount);
    event Unstaked(address account, uint256 amount);
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import './IBEP20.sol';
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";

/**
 * @title SafeBEP20
 * @dev Wrappers around BEP20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeBEP20 for IBEP20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeBEP20 {
    using SafeMath for uint256;
    using Address for address;

    function safeTransfer(
        IBEP20 token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(
        IBEP20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IBEP20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(
        IBEP20 token,
        address spender,
        uint256 value
    ) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        // solhint-disable-next-line max-line-length
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            'SafeBEP20: approve from non-zero to non-zero allowance'
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(
        IBEP20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender).add(value);
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(
        IBEP20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender).sub(
            value,
            'SafeBEP20: decreased allowance below zero'
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IBEP20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, 'SafeBEP20: low-level call failed');
        if (returndata.length > 0) {
            // Return data is optional
            // solhint-disable-next-line max-line-length
            require(abi.decode(returndata, (bool)), 'SafeBEP20: BEP20 operation did not succeed');
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;

abstract contract HolderController {
    
    /**
     * Struct for storing holdings data
     */
    struct Holding {
        bool holding; // whether address is currently holding
        uint256 adrIndex; // index of address in holders array
    }
    
    address[] internal _holders;
    mapping (address => Holding) internal _holdings;
    uint256 internal _holdersCount;
    
    function getHolders() public view returns (address[] memory) {
        return _holders;
    }
    
    function getHoldersCount() public view returns (uint256) {
        return _holdersCount;
    }
    
    function isHolder(address holder) public view returns (bool) {
        return _holdings[holder].holding;
    }
    
    function addHolder(address account) internal {
        _holdings[account].holding = true;
        _holdings[account].adrIndex = _holders.length;
        _holders.push(account);
        _holdersCount++;
    }

    function removeHolder(address account) internal {
        _holdings[account].holding = false;
        
        uint256 i = _holdings[account].adrIndex;
        _holders[i] = _holders[_holders.length-1];
        _holders.pop();
        _holdings[_holders[i]].adrIndex = i;        
        _holdersCount--;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "../utils/Context.sol";
/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor () internal {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.2 <0.8.0;

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
        return size > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{ value: amount }("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain`call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
      return functionCall(target, data, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value, string memory errorMessage) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.call{ value: value }(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data, string memory errorMessage) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.staticcall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    function _verifyCallResult(bool success, bytes memory returndata, string memory errorMessage) private pure returns(bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                // solhint-disable-next-line no-inline-assembly
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.2 <0.8.0;

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
        return size > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{ value: amount }("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain`call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
      return functionCall(target, data, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value, string memory errorMessage) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.call{ value: value }(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data, string memory errorMessage) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.staticcall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    function _verifyCallResult(bool success, bytes memory returndata, string memory errorMessage) private pure returns(bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                // solhint-disable-next-line no-inline-assembly
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}


// SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;

interface IPogBot {
    function callHook(address caller, address sender, address receiver, uint256 amount) external;
}

