// SPDX-License-Identifier: MIT 

pragma solidity ^0.8.21;

import "./Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

//A contract to handle the locking of tokens for a fixed duration with rewards
// Author Emmanuel Umoh

contract GenXLocker is Ownable
{
    using SafeERC20 for IERC20;

    // This struct holds data related to a stake's reward.
    struct Rewards {
        string lockedToken; //the ERC20 token being locked
        uint lockedAmount; //the amount of tokens locked
        uint startTime; //timestamp for the beginning of the stake
        uint endTime; //timestamp for the expiry of the stake
        bool lockState; // current state of the stake; true = active, false = expired
        uint stakeDuration; //lock duration in days
        uint computedRewards; //rewards calculated based on lock parameters
    }

    // This struct serves a record holder for a single staking transaction
    struct LockerItem {
        uint internalIndex; //index used to reference this record
        Rewards itemReward; //rewards related variables
        uint earnRate; //earning rate of staked tokens per second
        uint stakeAPY; //Annual expected yield, used to compute earn rate
    }

    // This struct represents a GenXLocker user and their stakes
    struct LockerUser {
        address userAddress;
        bool userExists; //flag to indicate if a user is a new or already existing user
        LockerItem[] stakes; //collection of the user's stake records
    }

    // A mapping of each supported stake token to their respective contract addresses
    mapping(string => address) private tokenContractMap;

    // A list of keys stored in the tokenContractMap
    string[] private tokenNameList;
    
    // A mapping of each user address to their corresponding stake records
    mapping(address => LockerUser) private stakersMap;

    // emitted when a user makes a new stake
    event NewStake(address userAddress, uint amount);

    // emitted when a user unlocks a stake
    event UnlockStake (address userAddres, uint unstakeAmount);

    constructor()
    {
        //initialize the contract with the default set of stake tokens
        setupStakeTokens();
    }

    //Populate the map of supported stake tokens. More tokens can later be added by the owner using the addStakeToken function
    function setupStakeTokens() internal onlyOwner
    {
        //Test USDC
        tokenContractMap["USDC"] = 0x53D77D4bDC7f34D2933936A01d854A3a59F9357f;
        tokenNameList.push("USDC");
        //World of Warcoins testUSDT
        tokenContractMap["WUSD"] = 0x009C0Cda7dfCD3911c4e55125AD090f0dEB97Db4;
        tokenNameList.push("WUSD");
    }

    // Adds a new token to the list of tokens that can be staked
    function addStakeToken(string memory tokenName, address tokenCA) external onlyOwner
    {
        tokenContractMap[tokenName] = tokenCA;
        tokenNameList.push(tokenName);
    }

    // Gets the list of supported tokens
    function getStakeTokens() external view returns(string[] memory)
    {
        return tokenNameList;
    }

    // Retrieves a user's record using their address
    function getStaker(address userAddr) external view returns(LockerUser memory)
    {
        return stakersMap[userAddr];
    }

    // Internal function to add a new user to the contract
    function addStaker(address userAddr) public pure returns(LockerUser memory)
    {
        LockerUser memory newUser;
        newUser.userAddress = userAddr;
        newUser.userExists = true;
        //stakersMap[userAddr] = newUser;
        return newUser;
    }

    // This function adds a new stake transaction to the user's account
    // Emits {NewStake} event
    
    function newLock(string memory stakeTokenName, uint duration, uint amount, uint apy) external
    {
        //Use msg.sender as userAddr to make the transaction more secure since we want only the 
        //caller's wallet to be able to perform this operation
        LockerUser memory staker = stakersMap[msg.sender];
        if(!staker.userExists){
            staker = addStaker(msg.sender);
            stakersMap[msg.sender] = staker;
        }
        doTransferFrom(stakeTokenName, amount, msg.sender);

        LockerItem memory stakeItem;
        stakeItem.itemReward.lockedToken = stakeTokenName;
        stakeItem.itemReward.lockedAmount = amount;
        stakeItem.itemReward.startTime = block.timestamp;
        stakeItem.itemReward.stakeDuration = duration;
        stakeItem.itemReward.endTime = getEndTime(duration, stakeItem.itemReward.startTime);
        stakeItem.itemReward.lockState = true;
        stakeItem.itemReward.computedRewards = 0;

        stakeItem.stakeAPY = apy;
        stakeItem.earnRate = computeRate(apy);
        stakeItem.internalIndex = staker.stakes.length;
        staker.stakes[stakeItem.internalIndex] =  stakeItem;

        emit NewStake(msg.sender, amount);
    }

    function getEndTime(uint duration, uint startTime) private pure returns(uint)
    {
        uint durationInSec = duration * 86400; //changes duration from days to seconds
        return startTime + durationInSec;
    }

    // function to tranfer the specified amount from the given address to this contract address
    function doTransferFrom(string memory tokenName, uint amt, address userAddr) private
    {
        IERC20 stakeToken = IERC20(tokenContractMap[tokenName]);
        stakeToken.safeTransferFrom(userAddr,address(this),amt);
    }

    // function to transfer the specified amount from this contract to the given address
    function doTransferTo(address userAddr, uint amt, string memory tokenName) private
    {
        IERC20 stakeToken = IERC20(tokenContractMap[tokenName]);
        stakeToken.safeTransfer(userAddr, amt);
    }

    // Compute the earn rate in seconds from the annual rate
    function computeRate(uint theApy) private pure returns(uint)
    {
        uint rate = (theApy/100.0)/31536000; // divide apy by total number of seconds in a year to get the rate per second
        return rate;
    }

    // Function to unlock a given stake
    // Emits a {UnlockStake} event
    function unlockStake(uint sIndex) external
    {
        //LockerUser memory staker = stakersMap[msg.sender];
        LockerItem memory stakeItem = stakersMap[msg.sender].stakes[sIndex];
        require(block.timestamp >= stakeItem.itemReward.endTime,"Stake has not expired");
        stakeItem.itemReward.lockState = false;
        stakeItem.itemReward.computedRewards = getRewards(stakeItem);
        uint unstakeAmount = stakeItem.itemReward.lockedAmount + stakeItem.itemReward.computedRewards;
        doTransferTo(msg.sender, unstakeAmount, stakeItem.itemReward.lockedToken);

        emit UnlockStake(msg.sender, unstakeAmount);
    }

    // Internal function to compute the rewards earned by a user based on the stake parameters
    function getRewards(LockerItem memory item) internal view returns(uint)
    {
        uint duration;
        if(item.itemReward.lockState){
            duration = block.timestamp - item.itemReward.startTime;
        }else{
            duration = item.itemReward.endTime - item.itemReward.startTime;
        }
        if(duration < 0) duration = 0;
        uint reward = item.itemReward.lockedAmount * item.earnRate * duration;
        return reward;
    }

    // Function calculates the rewards for all stakes in the specified array
    function calculateRewards(LockerItem[] memory stakes) private view returns(Rewards[] memory)
    {
        Rewards[] memory rewardList;
        for(uint i = 0;i < stakes.length;i++){
            stakes[i].itemReward.computedRewards = getRewards(stakes[i]);
            rewardList[i] = stakes[i].itemReward;
        }
        return rewardList;
    }

    // This function retrieves the collection of all stakes made by a specified user
    function getStakingData(address userAddr) external view returns(Rewards[] memory)
    {
        LockerUser memory user = stakersMap[userAddr];
        return calculateRewards(user.stakes);
    }
}
