function lock(uint256 time) public virtual onlyOwner {
  _previousOwner = _owner;
  _owner = address(0);
}
 
function unlock() public virtual {
  require(_previousOwner == msg.sender, );
  _owner = _previousOwner;
}