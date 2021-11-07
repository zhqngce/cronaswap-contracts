// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./CronaBar.sol";
import "./CronaToken.sol";

// MasterChef is the master of Crona. He can make Crona and he is a fair guy.
//
// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once CRONA is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract MasterChef is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount;     // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of CRONAs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accCronaPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accCronaPerShare` (and `lastRewardTime`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken;           // Address of LP token contract.
        uint256 allocPoint;       // How many allocation points assigned to this pool. CRONAs to distribute per second.
        uint256 lastRewardTime;  // Last second number that CRONAs distribution occurs.
        uint256 accCronaPerShare; // Accumulated CRONAs per share, times 1e12. See below.
    }

    // The CRONA TOKEN!
    CronaToken public crona;
    // The xCRONA TOKEN!
    CronaBar public xCrona;
    // Treasury address.
    address public treasury;
    // CRONA tokens created per second.
    uint256 public cronaPerSecond;
    // Bonus muliplier for early crona makers.
    uint256 public BONUS_MULTIPLIER = 1;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The second number when CRONA mining starts.
    uint256 public startTime;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);

    constructor(
        CronaToken _crona,
        CronaBar _xCrona,
        address _treasury,
        uint256 _cronaPerSecond,
        uint256 _startTime
    ) public {
        crona = _crona;
        xCrona = _xCrona;
        treasury = _treasury;
        cronaPerSecond = _cronaPerSecond;
        startTime = _startTime;

        // staking pool
        poolInfo.push(PoolInfo({
            lpToken: _crona,
            allocPoint: 1000,
            lastRewardTime: startTime,
            accCronaPerShare: 0
        }));

        totalAllocPoint = 1000;

    }

    function updateMultiplier(uint256 multiplierNumber) public onlyOwner {
        BONUS_MULTIPLIER = multiplierNumber;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(uint256 _allocPoint, IERC20 _lpToken, bool _withUpdate) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardTime = block.timestamp > startTime ? block.timestamp : startTime;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(PoolInfo({
            lpToken: _lpToken,
            allocPoint: _allocPoint,
            lastRewardTime: lastRewardTime,
            accCronaPerShare: 0
        }));
        updateStakingPool();
    }

    // Update the given pool's CRONA allocation point. Can only be called by the owner.
    function set(uint256 _pid, uint256 _allocPoint, bool _withUpdate) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 prevAllocPoint = poolInfo[_pid].allocPoint;
        poolInfo[_pid].allocPoint = _allocPoint;
        if (prevAllocPoint != _allocPoint) {
            totalAllocPoint = totalAllocPoint.sub(prevAllocPoint).add(_allocPoint);
            updateStakingPool();
        }
    }

    function updateStakingPool() internal {
        uint256 length = poolInfo.length;
        uint256 points = 0;
        for (uint256 pid = 1; pid < length; ++pid) {
            points = points.add(poolInfo[pid].allocPoint);
        }
        if (points != 0) {
            points = points.div(3);
            totalAllocPoint = totalAllocPoint.sub(poolInfo[0].allocPoint).add(points);
            poolInfo[0].allocPoint = points;
        }
    }

    // Return reward multiplier over the given _from to _to second.
    function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {
        return _to.sub(_from).mul(BONUS_MULTIPLIER);
    }

    // View function to see pending CRONAs on frontend.
    function pendingCrona(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accCronaPerShare = pool.accCronaPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.timestamp > pool.lastRewardTime && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardTime, block.timestamp);
            uint256 cronaReward = multiplier.mul(cronaPerSecond).mul(pool.allocPoint).div(totalAllocPoint);
            accCronaPerShare = accCronaPerShare.add(cronaReward.mul(1e12).div(lpSupply));
        }
        return user.amount.mul(accCronaPerShare).div(1e12).sub(user.rewardDebt);
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }


    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.timestamp <= pool.lastRewardTime) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastRewardTime = block.timestamp;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardTime, block.timestamp);
        uint256 cronaReward = multiplier.mul(cronaPerSecond).mul(pool.allocPoint).div(totalAllocPoint);
        crona.mint(treasury, cronaReward.div(10));
        crona.mint(address(xCrona), cronaReward);
        pool.accCronaPerShare = pool.accCronaPerShare.add(cronaReward.mul(1e12).div(lpSupply));
        pool.lastRewardTime = block.timestamp;
    }

    // Deposit LP tokens to MasterChef for CRONA allocation.
    function deposit(uint256 _pid, uint256 _amount) public {

        require (_pid != 0, 'deposit CRONA by staking');

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accCronaPerShare).div(1e12).sub(user.rewardDebt);
            if(pending > 0) {
                safeCronaTransfer(msg.sender, pending);
            }
        }
        if (_amount > 0) {
            pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            user.amount = user.amount.add(_amount);
        }
        user.rewardDebt = user.amount.mul(pool.accCronaPerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) public {

        require (_pid != 0, 'withdraw CRONA by unstaking');
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");

        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accCronaPerShare).div(1e12).sub(user.rewardDebt);
        if(pending > 0) {
            safeCronaTransfer(msg.sender, pending);
        }
        if(_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
        }
        user.rewardDebt = user.amount.mul(pool.accCronaPerShare).div(1e12);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Stake CRONA tokens to MasterChef
    function enterStaking(uint256 _amount) public {
        PoolInfo storage pool = poolInfo[0];
        UserInfo storage user = userInfo[0][msg.sender];
        updatePool(0);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accCronaPerShare).div(1e12).sub(user.rewardDebt);
            if(pending > 0) {
                safeCronaTransfer(msg.sender, pending);
            }
        }
        if(_amount > 0) {
            pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            user.amount = user.amount.add(_amount);
        }
        user.rewardDebt = user.amount.mul(pool.accCronaPerShare).div(1e12);

        xCrona.mint(msg.sender, _amount);
        emit Deposit(msg.sender, 0, _amount);
    }

    // Withdraw CRONA tokens from STAKING.
    function leaveStaking(uint256 _amount) public {
        PoolInfo storage pool = poolInfo[0];
        UserInfo storage user = userInfo[0][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(0);
        uint256 pending = user.amount.mul(pool.accCronaPerShare).div(1e12).sub(user.rewardDebt);
        if(pending > 0) {
            safeCronaTransfer(msg.sender, pending);
        }
        if(_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
        }
        user.rewardDebt = user.amount.mul(pool.accCronaPerShare).div(1e12);

        xCrona.burn(msg.sender, _amount);
        emit Withdraw(msg.sender, 0, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        pool.lpToken.safeTransfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
    }

    // Safe crona transfer function, just in case if rounding error causes pool to not have enough CRONAs.
    function safeCronaTransfer(address _to, uint256 _amount) internal {
        xCrona.safeCronaTransfer(_to, _amount);
    }

    function setCronaPerSecond(uint256 _cronaPerSecond) public onlyOwner {
        require(_cronaPerSecond <= 2 * 1e18, "Max per second 2 CRONA");
        massUpdatePools();
        cronaPerSecond = _cronaPerSecond;
    }

    // Update treasury address by the owner.
    function setTreasury(address _treasury) public onlyOwner {
        treasury = _treasury;
    }
}