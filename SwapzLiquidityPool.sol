// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


// This contract is owned by Decentralized Swapz Network

// Decentralized Swapz Network is Mesh network based on Threshold Signature Scheme with 2/3 PoS Consensus. 

// Crosschain Liquidity Pool
contract SwapzLiquidityPool is ERC20("LP Token", "LP"), Ownable {
    using SafeMath for uint256;
    ERC20 public stable;

    // Special fee for special network 
    mapping(uint => uint) public chainIdToFee;

    // get fee 
    function chainChainFee(uint chainId, uint fee) public onlyOwner {
        chainIdToFee[chainId] = fee;
    }

    // Define the token 
    constructor(address _stable) {
        stable = ERC20(_stable);
        chainIdToFee[97] = 0.001 ether;
        chainIdToFee[3] = 0.001 ether;
    }
    
    function decimals() public view virtual override returns (uint8) {
        return stable.decimals();
    }
    
    // Mash nodes connected to this event
    event CrossSwap ( address receiver, uint value, uint chainId );
    
    
    //function isContract(address addr) private view returns (bool) {
    //    uint size;
    //    assembly { size := extcodesize(addr) }
    //    return size > 0;
    //}
    
    
    
    function swapRequest(uint _amount, uint chainId) external payable {
        
        uint chainFee = chainIdToFee[chainId];
        
        require(chainFee > 0, "ChainId is unknown");
        
        require(msg.value > chainFee, "CrossSwap Fee is required for 3 cases: 1) swap back when not enough liqudity on foraign chain. 2) to cover fee on foragn chain. 3) incentive swapz oracles");
        
        //require(!isContract(msg.sender), "Smart Contract is not permitted");
        
        //totalLiquidity = totalLiquidity.add(_amount);
        
        // the transaction should reverted if not enough balance (each ERC20 should be audited)
        stable.transferFrom(msg.sender, address(this), _amount);
        
        payable(owner()).transfer(msg.value);

        emit CrossSwap(msg.sender, _amount, chainId);
        
    }
    
    function sendBackAll(address[] calldata keepers, uint[] calldata amounts, bytes[] calldata foreignTx) public onlyOwner {
        for (uint i = 0; i < keepers.length; i++) {
            sendBack(keepers[i], amounts[i], foreignTx[i]);
        }
    }
    
    function sendAll(address[] calldata keepers, uint[] calldata amounts, bytes[] calldata foreignTx) public onlyOwner {
        for (uint i = 0; i < keepers.length; i++) {
            send(keepers[i], amounts[i], foreignTx[i]);
        }
    }
    
    mapping(bytes => bool) public knownForainTxs; 
    
    //Send back tokens when there is no enough liqudity on foraign network
    function sendBack(address keeper, uint _amount, bytes calldata foreignTx) public onlyOwner {
        
        require(knownForainTxs[foreignTx] == false, "Already known tx");
        
        knownForainTxs[foreignTx] = true;
        
        //totalLiquidity = totalLiquidity.sub(_amount);
        
        // the transaction should reverted if not enough balance (each ERC20 should be audited)
        stable.transfer(keeper, _amount);
        
    }
    
    //Send Tokens to user who deposited USDT in ethereum network. The owner is Decentralized Swapz Network
    function send(address keeper, uint _amount, bytes calldata foreignTx) public onlyOwner {
        
        require(knownForainTxs[foreignTx] == false, "Already known tx");
        
        knownForainTxs[foreignTx] = true;
        
        uint fee = _amount.div(2500);
        
        uint finalAmount = _amount.sub(fee);
        
        uint meshFee = fee.div(4);
        
        uint lpFee = fee.sub(meshFee);
        
        totalLiquidity = totalLiquidity.add(lpFee); //.sub(_amount);
        
        require(totalLiquidity > 0, "Not enough liqudity");
        
        totalMeshFee = totalMeshFee.add(meshFee);
        // the transaction should reverted if not enough balance (each ERC20 should be audited)
        stable.transfer(keeper, finalAmount);
        
    }

    uint public totalLiquidity = 0;
    
    uint public totalMeshFee = 0; 
    
    // withdraw mesh fee
    function withdrawMeshFee(address where) onlyOwner public {
         // the transaction should reverted if not enough balance (each ERC20 should be audited)
         stable.transfer(where, totalMeshFee);
         totalMeshFee = 0;
    } 
    
    

    // Enter the bar. Pay some STABLE. Earn some shares.
    // Locks STABLE and mints LP tokens
    function join(uint256 _amount) public {
        
        //require(!isContract(msg.sender), "Smart Contract is not permitted");
        
        // Gets the amount of bBUSD_tUSDT in existence
        uint256 totalShares = totalSupply();
        // If no shares exist, mint it 1:1 to the amount put in
        if (totalShares == 0 || totalLiquidity == 0) {
            _mint(msg.sender, _amount);
        } 
        // Calculates the amount of shares are worth. The ratio will change overtime, as shares are burned/minted and STABLE deposited + gained from fees / withdrawn.
        else {
            uint256 what = _amount.mul(totalShares.div(10e12)).div(totalLiquidity.div(10e12));
            _mint(msg.sender, what);
        }
        // Lock the STABLE in the contract
        // the transaction should reverted (each ERC20 should be audited)
        stable.transferFrom(msg.sender, address(this), _amount);
        totalLiquidity = totalLiquidity.add(_amount);
        
    }

    function burn(uint256 _share) private returns(uint) {
        require(_share > 0, "Share amount should be greater than 0");
        // Gets the amount of bBUSD_tUSDT in existence
        uint256 totalShares = totalSupply();
        // Calculates the amount of shares are worth
        uint256 what = _share.mul(totalLiquidity.div(10e12)).div(totalShares.div(10e12));
        // burn LP tokens;
        _burn(msg.sender, _share);
        // Reduce stake
        totalLiquidity = totalLiquidity.sub(what);
        return what;
    }

    // Thats possible condition when STABLE is no longer available in this smart contract but STABLE is available in foreign contract. So this method ask Mesh Network to send tokens on the same address there
    function leaveForeign(uint256 _share, uint chainId) public payable {
        
        uint chainFee = chainIdToFee[chainId];
        
        require(chainFee > 0, "ChainId is unknown");
        
        require(msg.value > chainFee, "CrossSwap Fee is required for 3 cases: 1) swap back when not enough liqudity on foraign chain. 2) to cover fee on foragn chain. 3) incentive swapz oracles");
        
        uint256 what = burn(_share);
        
        emit CrossSwap(msg.sender,  what, chainId);
    }

    // Leave the bar. Claim back your STABLE.
    // Unlocks the staked + gained STABLE and burns share
    function leave(uint256 _share) public {
        
        uint256 what = burn(_share);
        // the transaction should reverted if not enough balance (each ERC20 should be audited)
        stable.transfer(msg.sender, what);
    }
}



