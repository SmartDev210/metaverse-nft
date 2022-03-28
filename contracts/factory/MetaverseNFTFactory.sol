// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./MetaverseNFT.sol";

/**
* MetaverseNFT is a cloneable contract for your NFT collection.
* It's adapted from OpenZeppeling ERC721 implementation upgradeable versions.
* This is needed to make it possible to create clones that work via delegatecall
* ! The constructor is replaced with initializer, too
* This way, deployment costs about 350k gas instead of 4.5M.
* 1. https://forum.openzeppelin.com/t/how-to-set-implementation-contracts-for-clones/6085/4
* 2. https://github.com/OpenZeppelin/workshops/tree/master/02-contracts-clone/contracts/2-uniswap
* 3. https://docs.openzeppelin.com/contracts/4.x/api/proxy
*/

contract MetaverseNFTFactory is Ownable {

    address public immutable proxyImplementation;
    IERC721 public earlyAccessPass;

    event NFTCreated(
        address deployedAddress,
        // creation parameters
        uint256 price,
        uint256 maxSupply,
        uint256 nReserved,
        string name,
        string symbol
    );

    modifier hasAccess(address creator) {
        // check that creator owns NFT
        require(address(earlyAccessPass) == address(0) || earlyAccessPass.balanceOf(msg.sender) > 0, "MetaverseNFTFactory: Early Access Pass is required");
        _;
    }

    constructor(address _earlyAccessPass) {
        proxyImplementation = address(new MetaverseNFT());

        earlyAccessPass = IERC721(_earlyAccessPass);

        emit NFTCreated(
            proxyImplementation,
            0,
            0,
            0,
            "IMPLEMENTATION",
            "IMPLEMENTATION"
        );
    }

    function updateEarlyAccessPass(address _earlyAccessPass) public onlyOwner {
        earlyAccessPass = IERC721(_earlyAccessPass);
    }

    function createNFT(
        uint256 _startPrice,
        uint256 _maxSupply,
        uint256 _nReserved,
        uint256 _maxTokensPerMint,
        uint256 _royaltyFee,
        string memory _uri,
        string memory _name, string memory _symbol
    ) external hasAccess(msg.sender) {

        address clone = Clones.clone(proxyImplementation);

        MetaverseNFT(payable(clone)).initialize(
            _startPrice,
            _maxSupply,
            _nReserved,
            _maxTokensPerMint,
            _royaltyFee,
            _uri,
            _name, _symbol,
            false
        );

        MetaverseNFT(payable(clone)).transferOwnership(msg.sender);

        emit NFTCreated(
            clone,
            _startPrice,
            _maxSupply,
            _nReserved,
            _name,
            _symbol
        );

    }

    function createNFTwithParams(
        uint256 _startPrice,
        uint256 _maxSupply,
        uint256 _nReserved,
        uint256 _maxTokensPerMint,
        uint256 _royaltyFee,
        string memory _uri,
        string memory _name, string memory _symbol,
        address payoutReceiver,
        bool shouldUseJSONExtension,
        uint16 miscParams
    ) external hasAccess(msg.sender) {

        address clone = Clones.clone(proxyImplementation);

        // params is a bitmask of:

        // bool startTokenIdAtOne = (miscParams & 0x01) == 0x01;
        // bool shouldUseJSONExtension = (miscParams & 0x02) == 0x02;
        // bool shouldStartSale = (miscParams & 0x04) == 0x04;
        // bool shouldLockPayoutChange = (miscParams & 0x08) == 0x08;

        MetaverseNFT(payable(clone)).initialize(
            _startPrice,
            _maxSupply,
            _nReserved,
            _maxTokensPerMint,
            _royaltyFee,
            _uri,
            _name, _symbol,
            (miscParams & 0x01) == 0x01
        );

        if (shouldUseJSONExtension) {
            MetaverseNFT(payable(clone)).setPostfixURI(".json");
        }

        if ((miscParams & 0x04) == 0x04) {
            MetaverseNFT(payable(clone)).startSale();
        }

        if (payoutReceiver != address(0)) {
            MetaverseNFT(payable(clone)).setPayoutReceiver(payoutReceiver);
        }

        if ((miscParams & 0x08) == 0x08) {
            MetaverseNFT(payable(clone)).lockPayoutChange();
        }

        MetaverseNFT(payable(clone)).transferOwnership(msg.sender);
 
        emit NFTCreated(
            clone,
            _startPrice,
            _maxSupply,
            _nReserved,
            _name,
            _symbol
        );
    }

}
