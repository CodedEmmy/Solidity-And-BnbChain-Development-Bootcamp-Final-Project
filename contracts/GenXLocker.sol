// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.21;

import "./Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/** 
@title A contract to handle the locking of tokens for a fixed duration with rewards
@author Emmanuel Umoh
 */
contract GenXLocker is Ownable
{
    using SafeERC20 for IERC20;

    //@notice This struct serves a record holder for a single staking transaction
    struct LockerItem{
        string lockedToken; //the ERC20 token being locked
        uint lockedAmount; //the amount of tokens locked
        uint startTime; //timestamp for the beginning of the stake
        uint endTime; //timestamp for the expiry of the stake
        uint earnRate; //earning rate of staked tokens per second
        uint stakeDuration; //lock duration in days
        uint computedRewards; //rewards calculated based on lock parameters
        uint stakeAPY; //Annual expected yield, used to compute earn rate
        bool lockState; // current state of the stake; true = active, false = expired
        uint internalIndex; //index used to reference this record
    }

    //@notice This struct represents a GenXLocker user and their stakes
    struct LockerUser{
        address userAddress;
        bool userExists; //flag to indicate if a user is a new or already existing user
        LockerItem[] stakes; //collection of the user's stake records
    }

    //@notice A mapping of each supported stake token to their respective contract addresses
    mapping(string => address) tokenContractMap;

    //@notice A list of keys stored in the tokenContractMap
    string[] tokenNameList;
    
    //@notice A mapping of each user address to their corresponding stake records
    mapping(address => LockerUser) stakersMap;

    // emitted when a user makes a new stake
    event NewStake(address userAddress, uint amount);

    // emitted when a user unlocks a stake
    event UnlockStake (address userAddres, uint unstakeAmount);

    constructor()
    {
        //initialize the contract with the default set of stake tokens
        setupStakeTokens();
    }

    /**
    @notice populate the map of supported stake tokens. More tokens can later be added by the owner using the addStakeToken function
     */
    function setupStakeTokens() internal onlyOwner
    {
        //Test USDC
        tokenContractMap["USDC"] = 0x53D77D4bDC7f34D2933936A01d854A3a59F9357f;
        tokenNameList.push("USDC");
        //World of Warcoins testUSDT
        tokenContractMap["WUSD"] = 0x009C0Cda7dfCD3911c4e55125AD090f0dEB97Db4;
        tokenNameList.push("WUSD");
    }

    /**
    @notice Adds a new token to the list of tokens that can be staked
    @param tokenName string name for the token
    @param tokenCA the token's contract address
     */
    function addStakeToken(string memory tokenName, address tokenCA) external onlyOwner
    {
        tokenContractMap[tokenName] = tokenCA;
        tokenNameList.push(tokenName);
    }

    /**
    @notice gets the list of supported tokens
    @return string[] array containing the supported token names
     */
    function getStakeTokens() public view returns(string[] memory)
    {
        return tokenNameList;
    }

    /**
    @notice retrieves a user's record using their address
    @param userAddr User's address
    @return LockerUser object holding the stake records for the specified address
     */
    function getStaker(address userAddr) public view returns(LockerUser memory)
    {
        return stakersMap[userAddr];
    }

    /**
    * Internal function to add a new user to the contract
     */
    function addStaker(address userAddr) public pure returns(LockerUser memory)
    {
        LockerUser memory newUser;
        newUser.userAddress = userAddr;
        newUser.userExists = true;
        //stakersMap[userAddr] = newUser;
        return newUser;
    }

    /**
    * This function adds a new stake transaction to the user's account
    * @param stakeTokenName the name of the token to stake
    * @param duration period of the lock (in days)
    * @param amount number of tokens to be staked
    * @param apy the APY
    *
    * Emits {NewStake} event
     */
    function newLock(string memory stakeTokenName, uint duration, uint amount, uint apy) public
    {
        //Use msg.sender as userAddr to make the transaction more secure since we want only the 
        //caller's wallet to be able to perform this operation
        address userAddr = msg.sender;
        LockerUser memory staker = stakersMap[userAddr];
        if(!staker.userExists){
            staker = addStaker(userAddr);
            stakersMap[userAddr] = staker;
        }
        IERC20 stakeToken = IERC20(tokenContractMap[stakeTokenName]);
        stakeToken.safeTransferFrom(userAddr,address(this),amount);
        LockerItem memory stakeItem;
        stakeItem.lockedToken = stakeTokenName;
        stakeItem.lockedAmount = amount;
        stakeItem.startTime = block.timestamp;
        stakeItem.stakeDuration = duration;
        uint durationInSec = duration * 86400; //changes duration from days to seconds
        stakeItem.endTime = stakeItem.startTime + durationInSec;
        stakeItem.stakeAPY = apy;
        stakeItem.earnRate = computeRate(apy);
        stakeItem.lockState = true;
        stakeItem.computedRewards = 0;
        stakeItem.internalIndex = staker.stakes.length;
        staker.stakes[stakeItem.internalIndex] =  stakeItem;

        emit NewStake(userAddr, amount);
    }

    /**
    * Compute the earn rate in seconds from the annual rate
     */
    function computeRate(uint theApy) private pure returns(uint)
    {
        uint rate = (theApy/100.0)/31536000; // divide apy by total number of seconds in a year to get the rate per second
        return rate;
    }

    /**
    * function to unlock a given stake
    * @param sIndex index used to identify the particular stake record. Index is obtained from the internalIndex member of the LockerItem
    *
    * Emits a {UnlockStake} event
     */
    function unlockStake(uint sIndex) external
    {
        address userAddr = msg.sender;
        LockerUser memory staker = stakersMap[userAddr];
        LockerItem memory stakeItem = staker.stakes[sIndex];
        require(block.timestamp >= stakeItem.endTime,"Stake has not expired");
        stakeItem.lockState = false;
        stakeItem.computedRewards = getRewards(stakeItem);
        IERC20 stakeToken = IERC20(tokenContractMap[stakeItem.lockedToken]);
        uint unstakeAmount = stakeItem.lockedAmount + stakeItem.computedRewards;
        stakeToken.safeTransfer(userAddr, unstakeAmount);

        emit UnlockStake(userAddr, unstakeAmount);
    }

    /**
    * Internal function to compute the rewards earned by a user based on the stake parameters
    * @param item LockerItem representing a particular staking record
    * @return uint the computed reward amount
     */
    function getRewards(LockerItem memory item) internal view returns(uint)
    {
        uint duration;
        if(item.lockState){
            duration = block.timestamp - item.startTime;
        }else{
            duration = item.endTime - item.startTime;
        }
        if(duration < 0) duration = 0;
        uint reward = item.lockedAmount * item.earnRate * duration;
        return reward;
    }

    /**
    * Function calculates the rewards for all stakes in the specified array
    * @param li array of LockerItems containing stakes whose rewards we which to calculate
    * @return LockerItem[] the array of LockerItems with computed rewards
     */
    function calculateRewards(LockerItem[] memory li) private view returns(LockerItem[] memory)
    {
        LockerItem[] memory stakes = li;
        for(uint i = 0;i < stakes.length;i++){
            stakes[i].computedRewards = getRewards(stakes[i]);
        }
        return stakes;
    }

    /**
    * This function retrieves the collection of all stakes made by a specified user
    * @param userAddr address of target user
    * @return LockerItem an array of LockerItem objects
     */
    function getStakingData(address userAddr) public view returns(LockerItem[] memory)
    {
        LockerUser memory user = stakersMap[userAddr];
        return calculateRewards(user.stakes);
    }
}
