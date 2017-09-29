pragma solidity ^0.4.11;

import "../zeppelin-solidity/contracts/token/StandardToken.sol";

contract SmokeExchangeToken is StandardToken {
  string public name = "Smoke Exchange Token";
  string public symbol = "SMX";
  uint256 public decimals = 18;  
  address public ownerAddress;
    
  event Distribute(address indexed to, uint256 value);
  
  function SmokeExchangeToken(uint256 _totalSupply, address _ownerAddress, address smxTeamAddress, uint256 allocCrowdsale, uint256 allocAdvBounties, uint256 allocTeam) {
    ownerAddress = _ownerAddress;
    totalSupply = _totalSupply;
    balances[ownerAddress] += allocCrowdsale;
    balances[ownerAddress] += allocAdvBounties;
    balances[smxTeamAddress] += allocTeam;
  }
  
  function distribute(address _to, uint256 _value) returns (bool) {
    require(balances[ownerAddress] >= _value);
    balances[ownerAddress] = balances[ownerAddress].sub(_value);
    balances[_to] = balances[_to].add(_value);
    Distribute(_to, _value);
    return true;
  }
}