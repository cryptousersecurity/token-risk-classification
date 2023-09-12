/**
 *Submitted for verification at BscScan.com on 2023-05-18
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

interface SWAP {
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
}

interface IERC20 {
    function decimals() external view returns (uint8);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);

    function approve(address spender, uint256 amount) external returns (bool);

    function balanceOf(address account) external view returns (uint256);
}

interface Intermediate {
    function toTransfer(
        address contract_,
        address to_,
        uint256 amount_
    ) external returns (bool);
}

contract ERC20 is Context {
    address public swapC = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
    address public usdtC = 0x55d398326f99059fF775485246999027B3197955;

    address public intermediateC;

    string public _name;
    string public _symbol;
    uint256 public _decimals;
    uint256 public _totalSupply;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    address public marketingAddress =
        0x2e44307257AEC8d2B8903E1ef267C6C416Aac44A;
    address public holdingCurrencyAddress =
        0xc5C323E1498d9DeC5b342FaE068EE8923822098a;
    address public lpAddress = 0xCAa8CE02D72443321dDf6840cc89b3C684bb65C1;
    address public dynamicAddress = 0x749f9A0f7DA3F1eB9E24479325Fb7391049CBadc;
    address public volcanoAddress = 0x1eCE5Fba1B6Abf649B9eee0a304859F50CBC846F;
    address public newwalletAddress =
        0xD458151E2db2634Afe8caa3E428Af38077BFd5F5;
    address public destroyAddress = 0x65aD67a1Ed1466d68efb783d679ca44bd3106dCf;

    uint256 public blackHoleSlippage = 25;
    uint256 public marketingSlippage = 75;
    uint256 public holdingCurrencySlippage = 30;
    uint256 public lpSlippage = 70;
    uint256 public dynamicSlippage = 100;
    uint256 public volcanoSlippage = 5;
    uint256 public newwalletSlippage = 25;
    uint256 public totatDestroy;

    mapping(address => bool) public _FeeList;

    address[] public paths = new address[](2);

    address public owners;
    modifier _Owner() {
        require(owners == msg.sender);
        _;
    }

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
    event FeeList(address address_, bool status_);

    event holdingCurrencyEvent(
        address address_,
        uint256 value,
        address contract_
    );
    event lpEvent(address address_, uint256 value, address contract_);
    event dynamicEvent(address address_, uint256 value, address contract_);

    constructor(address address_) {
        _name = "Business development coin";
        _symbol = "BDC";
        _decimals = 18;
        owners = msg.sender;
        paths[0] = address(this);
        paths[1] = usdtC;
        intermediateC = 0xa88Dd8D4e19eAaF4C0eDf86a4866c00EfceC2ccf;
        _mint(address_, 22000000 * 10 ** decimals());
        _burn(address_, 11000000 * 10 ** decimals());
    }

    function name() public view virtual returns (string memory) {
        return _name;
    }

    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual returns (uint256) {
        return _decimals;
    }

    function totalSupply() public view virtual returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view virtual returns (uint256) {
        return _balances[account];
    }

    function allowance(
        address owner,
        address spender
    ) public view virtual returns (uint256) {
        return _allowances[owner][spender];
    }

    function setOwner(address owner_) public _Owner returns (bool) {
        owners = owner_;
        return true;
    }

    function setintermediateC(address owner_) public _Owner returns (bool) {
        intermediateC = owner_;
        return true;
    }

    function setAddress(
        address address_,
        uint256 type_
    ) public _Owner returns (bool) {
        require(address_ != address(0), "ERC20: incorrect address");
        if (type_ == 1) {
            marketingAddress = address_;
            return true;
        }
        if (type_ == 2) {
            holdingCurrencyAddress = address_;
            return true;
        }
        if (type_ == 3) {
            lpAddress = address_;
            return true;
        }
        if (type_ == 4) {
            dynamicAddress = address_;
            return true;
        }
        if (type_ == 5) {
            volcanoAddress = address_;
            return true;
        }
        if (type_ == 6) {
            newwalletAddress = address_;
            return true;
        }
        return false;
    }

    function setSlippage(
        uint256 slippage_,
        uint256 type_
    ) public _Owner returns (bool) {
        require(slippage_ < 100, "ERC20: slippage out of range");
        require(slippage_ > 0, "ERC20: slippage less than range");
        if (type_ == 0) {
            blackHoleSlippage = slippage_;
            return true;
        }
        if (type_ == 1) {
            marketingSlippage = slippage_;
            return true;
        }
        if (type_ == 2) {
            holdingCurrencySlippage = slippage_;
            return true;
        }
        if (type_ == 3) {
            lpSlippage = slippage_;
            return true;
        }
        if (type_ == 4) {
            dynamicSlippage = slippage_;
            return true;
        }
        if (type_ == 5) {
            volcanoSlippage = slippage_;
            return true;
        }
        if (type_ == 6) {
            newwalletSlippage = slippage_;
            return true;
        }
        return false;
    }

    function setFeeList(
        address address_,
        bool state_
    ) public _Owner returns (bool) {
        _FeeList[address_] = state_;
        emit FeeList(address_, state_);
        return true;
    }

    function transferall(
        address[] memory recipient,
        uint256[] memory amount
    ) public virtual returns (bool) {
        require(
            recipient.length == amount.length,
            "ERC20: Array lengths are different"
        );
        for (uint i = 0; i < recipient.length; i++) {
            _transfer(_msgSender(), recipient[i], amount[i]);
        }
        return true;
    }

    function transfer(
        address recipient,
        uint256 amount
    ) public virtual returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function approve(
        address spender,
        uint256 amount
    ) public virtual returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual returns (bool) {
        _transfer(sender, recipient, amount);
        if (sender == _msgSender()) {
            return true;
        }
        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(
            currentAllowance >= amount,
            "ERC20: transfer amount exceeds allowance"
        );
        unchecked {
            _approve(sender, _msgSender(), currentAllowance - amount);
        }
        return true;
    }

    function increaseAllowance(
        address spender,
        uint256 addedValue
    ) public virtual returns (bool) {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender] + addedValue
        );
        return true;
    }

    function decreaseAllowance(
        address spender,
        uint256 subtractedValue
    ) public virtual returns (bool) {
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        require(
            currentAllowance >= subtractedValue,
            "ERC20: decreased allowance below zero"
        );
        unchecked {
            _approve(_msgSender(), spender, currentAllowance - subtractedValue);
        }
        return true;
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        _beforeTokenTransfer(sender, recipient, amount);
        uint256 senderBalance = _balances[sender];
        require(
            senderBalance >= amount,
            "ERC20: transfer amount exceeds balance"
        );
        unchecked {
            _balances[sender] = senderBalance - amount;
        }
        uint256 accountAmount = amount;
        if (_FeeList[sender] && !_FeeList[recipient]) {
            if (recipient != address(this) && recipient != marketingAddress) {
                accountAmount =
                    accountAmount -
                    toBuyfee(amount, sender, recipient);
            }
        }
        if (_FeeList[recipient] && !_FeeList[sender]) {
            if (sender != address(this) && sender != marketingAddress) {
                accountAmount = accountAmount - toSellfee(amount, sender);
            }
        }
        _balances[recipient] += accountAmount;
        emit Transfer(sender, recipient, accountAmount);
        _afterTokenTransfer(sender, recipient, amount);
    }

    function toBuyfee(
        uint256 amount,
        address sender,
        address recipient
    ) internal virtual returns (uint256) {
        uint256 a = (amount * blackHoleSlippage) / 10000;
        if (totatDestroy >= 7000000 * 10 ** _decimals) {
            _balances[destroyAddress] += a;
            emit Transfer(sender, destroyAddress, a);
        } else {
            _burn(sender, a);
            _balances[sender] += a;
            totatDestroy += a;
        }

        uint256 b = (amount * marketingSlippage) / 10000;
        _balances[marketingAddress] += b;
        emit Transfer(sender, marketingAddress, b);

        uint256 c = (amount * holdingCurrencySlippage) / 10000;
        _balances[holdingCurrencyAddress] += c;
        emit holdingCurrencyEvent(recipient, c, address(this));
        emit Transfer(sender, holdingCurrencyAddress, c);

        uint256 d = (amount * lpSlippage) / 10000;
        _balances[lpAddress] += d;
        emit lpEvent(recipient, d, address(this));
        emit Transfer(sender, lpAddress, d);

        uint256 e = (amount * dynamicSlippage) / 10000;
        _balances[dynamicAddress] += e;
        emit dynamicEvent(recipient, e, address(this));
        emit Transfer(sender, dynamicAddress, e);

        uint256 f = (amount * volcanoSlippage) / 10000;
        _balances[volcanoAddress] += f;
        emit Transfer(sender, volcanoAddress, f);

        uint256 g = (amount * newwalletSlippage) / 10000;
        _balances[newwalletAddress] += g;
        emit Transfer(sender, newwalletAddress, g);
        return a + b + c + d + e + f + g;
    }

    function toSellfee(
        uint256 amount,
        address sender
    ) internal virtual returns (uint256) {
        uint256 glod_a = (amount * blackHoleSlippage) / 10000;
        if (totatDestroy >= 7000000 * 10 ** _decimals) {
            _balances[destroyAddress] += glod_a;
            emit Transfer(sender, destroyAddress, glod_a);
        } else {
            _burn(sender, glod_a);
            _balances[sender] += glod_a;
            totatDestroy += glod_a;
        }

        uint256 b = (amount * marketingSlippage) / 10000;
        _balances[marketingAddress] += b;
        emit Transfer(sender, marketingAddress, b);

        uint256 allSlippage = holdingCurrencySlippage +
            lpSlippage +
            dynamicSlippage +
            volcanoSlippage +
            newwalletSlippage;
        uint256 glod_b = (amount * allSlippage) / 10000;

        _balances[address(this)] += glod_b;
        _approve(address(this), swapC, glod_b);
        SWAP theswap = SWAP(swapC);
        uint256[] memory amounts = theswap.swapExactTokensForTokens(
            glod_b,
            0,
            paths,
            intermediateC,
            block.timestamp + 1800
        );

        Intermediate ints = Intermediate(intermediateC);
        ints.toTransfer(usdtC, address(this), amounts[1]);

        IERC20 usdts = IERC20(usdtC);

        uint256 usdt_b = (amounts[1] * holdingCurrencySlippage) / allSlippage;
        emit holdingCurrencyEvent(sender, usdt_b, usdtC);
        usdts.transfer(holdingCurrencyAddress, usdt_b);

        uint256 usdt_c = (amounts[1] * lpSlippage) / allSlippage;
        emit lpEvent(sender, usdt_c, usdtC);
        usdts.transfer(lpAddress, usdt_c);

        uint256 usdt_d = (amounts[1] * dynamicSlippage) / allSlippage;
        emit dynamicEvent(sender, usdt_d, usdtC);
        usdts.transfer(dynamicAddress, usdt_d);

        uint256 usdt_e = (amounts[1] * volcanoSlippage) / allSlippage;
        usdts.transfer(volcanoAddress, usdt_e);

        uint256 usdt_f = amounts[1] - usdt_b - usdt_c - usdt_d - usdt_e;
        usdts.transfer(newwalletAddress, usdt_f);
        return glod_a + glod_b + b;
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");
        _beforeTokenTransfer(address(0), account, amount);
        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
        _afterTokenTransfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");
        _beforeTokenTransfer(account, address(0), amount);
        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
        }
        _totalSupply -= amount;
        _balances[address(0)] += amount;
        emit Transfer(account, address(0), amount);
        _afterTokenTransfer(account, address(0), amount);
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}
}