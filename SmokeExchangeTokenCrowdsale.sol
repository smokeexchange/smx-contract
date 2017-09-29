pragma solidity ^0.4.11;

import "SmokeExchangeToken.sol";
import "../zeppelin-solidity/contracts/math/SafeMath.sol";
import "../zeppelin-solidity/contracts/ownership/Ownable.sol";

contract SmokeExchangeTokenCrowdsale is Ownable {
  using SafeMath for uint256;

  // The token being sold
  SmokeExchangeToken public token;
  
  // start and end timestamps where investments are allowed (both inclusive)
  uint256 public startTime;
  uint256 public endTime;
  uint256 public privateStartTime;
  uint256 public privateEndTime;

  // address where funds are collected
  address public wallet;

  // amount of raised money in wei
  uint256 public weiRaised;
  
  uint private constant DECIMALS = 1000000000000000000;
  //PRICES
  uint public constant TOTAL_SUPPLY = 28500000 * DECIMALS; //28.5 millions
  uint public constant BASIC_RATE = 300; //300 tokens per 1 eth
  uint public constant PRICE_STANDARD    = BASIC_RATE * DECIMALS; 
  uint public constant PRICE_PREBUY = PRICE_STANDARD * 150/100;
  uint public constant PRICE_STAGE_ONE   = PRICE_STANDARD * 125/100;
  uint public constant PRICE_STAGE_TWO   = PRICE_STANDARD * 115/100;
  uint public constant PRICE_STAGE_THREE   = PRICE_STANDARD * 107/100;
  uint public constant PRICE_STAGE_FOUR = PRICE_STANDARD;
  
  uint public constant PRICE_PREBUY_BONUS = PRICE_STANDARD * 165/100;
  uint public constant PRICE_STAGE_ONE_BONUS = PRICE_STANDARD * 145/100;
  uint public constant PRICE_STAGE_TWO_BONUS = PRICE_STANDARD * 125/100;
  uint public constant PRICE_STAGE_THREE_BONUS = PRICE_STANDARD * 115/100;
  uint public constant PRICE_STAGE_FOUR_BONUS = PRICE_STANDARD;
  
  //uint public constant PRICE_WHITELIST_BONUS = PRICE_STANDARD * 165/100;
  
  //TIME LIMITS
  uint public constant STAGE_ONE_TIME_END = 1 weeks;
  uint public constant STAGE_TWO_TIME_END = 2 weeks;
  uint public constant STAGE_THREE_TIME_END = 3 weeks;
  uint public constant STAGE_FOUR_TIME_END = 4 weeks;
  
  uint public constant ALLOC_CROWDSALE = TOTAL_SUPPLY * 75/100;
  uint public constant ALLOC_TEAM = TOTAL_SUPPLY * 15/100;  
  uint public constant ALLOC_ADVISORS_BOUNTIES = TOTAL_SUPPLY * 10/100;
  
  uint256 public smxSold = 0;
  
  address public ownerAddress;
  address public smxTeamAddress;
  
  //active = false/not active = true
  bool public halted;
  
  //in wei
  uint public cap; 
  
  //in wei, prebuy hardcap
  uint public privateCap;
  
  uint256 public bonusThresholdWei;
  
  /**
   * event for token purchase logging
   * @param purchaser who paid for the tokens
   * @param beneficiary who got the tokens
   * @param value weis paid for purchase
   * @param amount amount of tokens purchased
   */ 
  event TokenPurchase(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);
  
  /**
  * Modifier to run function only if contract is active (not halted)
  */
  modifier isNotHalted() {
    require(!halted);
    _;
  }
  
  /**
  * Constructor for SmokeExchageCoinCrowdsale
  * @param _privateStartTime start time for presale
  * @param _startTime start time for public sale
  * @param _ethWallet all incoming eth transfered here. Use multisig wallet
  * @param _privateWeiCap hard cap for presale
  * @param _weiCap hard cap in wei for the crowdsale
  * @param _bonusThresholdWei in wei. Minimum amount of wei required for bonus
  * @param _smxTeamAddress team address 
  */
  function SmokeExchangeTokenCrowdsale(uint256 _privateStartTime, uint256 _startTime, address _ethWallet, uint256 _privateWeiCap, uint256 _weiCap, uint256 _bonusThresholdWei, address _smxTeamAddress) {
    require(_privateStartTime >= now);
    require(_ethWallet != 0x0);    
    require(_smxTeamAddress != 0x0);    
    
    privateStartTime = _privateStartTime;
    //presale 10 days
    privateEndTime = privateStartTime + 10 days;    
    startTime = _startTime;
    
    //ICO start time after presale end
    require(_startTime >= privateEndTime);
    
    endTime = _startTime + STAGE_FOUR_TIME_END;
    
    wallet = _ethWallet;   
    smxTeamAddress = _smxTeamAddress;
    ownerAddress = msg.sender;
    
    cap = _weiCap;    
    privateCap = _privateWeiCap;
    bonusThresholdWei = _bonusThresholdWei;
                 
    token = new SmokeExchangeToken(TOTAL_SUPPLY, ownerAddress, smxTeamAddress, ALLOC_CROWDSALE, ALLOC_ADVISORS_BOUNTIES, ALLOC_TEAM);
  }
  
  // fallback function can be used to buy tokens
  function () payable {
    buyTokens(msg.sender);
  }
  
  // @return true if investors can buy at the moment
  function validPurchase() internal constant returns (bool) {
    bool privatePeriod = now >= privateStartTime && now < privateEndTime;
    bool withinPeriod = (now >= startTime && now <= endTime) || (privatePeriod);
    bool nonZeroPurchase = (msg.value != 0);
    //cap depends on stage.
    bool withinCap = privatePeriod ? (weiRaised.add(msg.value) <= privateCap) : (weiRaised.add(msg.value) <= cap);
    // check if there are smx token left
    bool smxAvailable = (ALLOC_CROWDSALE - smxSold > 0); 
    return withinPeriod && nonZeroPurchase && withinCap && smxAvailable;
    //return true;
  }

  // @return true if crowdsale event has ended
  function hasEnded() public constant returns (bool) {
    bool capReached = weiRaised >= cap;
    bool tokenSold = ALLOC_CROWDSALE - smxSold == 0;
    bool timeEnded = now > endTime;
    return timeEnded || capReached || tokenSold;
  }  
  
  /**
  * Main function for buying tokens
  * @param beneficiary purchased tokens go to this address
  */
  function buyTokens(address beneficiary) payable isNotHalted {
    require(beneficiary != 0x0);
    require(validPurchase());

    uint256 weiAmount = msg.value;

    // calculate token amount to be distributed
    uint256 tokens = SafeMath.div(SafeMath.mul(weiAmount, getCurrentRate(weiAmount)), 1 ether);
    //require that there are more or equal tokens available for sell
    require(ALLOC_CROWDSALE - smxSold >= tokens);

    //update total weiRaised
    weiRaised = weiRaised.add(weiAmount);
    //updated total smxSold
    smxSold = smxSold.add(tokens);
    
    //add token to beneficiary and subtract from ownerAddress balance
    token.distribute(beneficiary, tokens);
    TokenPurchase(msg.sender, beneficiary, weiAmount, tokens);

    //forward eth received to walletEth
    forwardFunds();
  }
  
  // send ether to the fund collection wallet  
  function forwardFunds() internal {
    wallet.transfer(msg.value);
  }
  
  /**
  * @param uint256 _weiAmount Wei amount to calculate bonus
  * Get rate. Depends on current time
  */
  function getCurrentRate(uint256 _weiAmount) constant returns (uint256) {  
      
      bool hasBonus = _weiAmount >= bonusThresholdWei;
  
      if (now < startTime) {
        return hasBonus ? PRICE_PREBUY_BONUS : PRICE_PREBUY;
      }
      uint delta = SafeMath.sub(now, startTime);

      //3+weeks from start
      if (delta > STAGE_THREE_TIME_END) {
        return hasBonus ? PRICE_STAGE_FOUR_BONUS : PRICE_STAGE_FOUR;
      }
      //2+weeks from start
      if (delta > STAGE_TWO_TIME_END) {
        return hasBonus ? PRICE_STAGE_THREE_BONUS : PRICE_STAGE_THREE;
      }
      //1+week from start
      if (delta > STAGE_ONE_TIME_END) {
        return hasBonus ? PRICE_STAGE_TWO_BONUS : PRICE_STAGE_TWO;
      }

      //less than 1 week from start
      return hasBonus ? PRICE_STAGE_ONE_BONUS : PRICE_STAGE_ONE;
  }
  
  /**
  * @param bool _halted
  * Enable/disable halted
  */
  function toggleHalt(bool _halted) onlyOwner {
    halted = _halted;
  }
}