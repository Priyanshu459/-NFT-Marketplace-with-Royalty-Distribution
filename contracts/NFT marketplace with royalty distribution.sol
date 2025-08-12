// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import   "@openzeppelin/contracts/access/Ownable.sol";

contract NFTMarketplaceWithRoyalty is ERC721URIStorage, Ownable {
    uint256 public tokenCounter;
    uint256 public marketplaceFee = 250; // 2.5%
    address public feeRecipient;
    
    struct Listing {
        address seller;
        uint256 price;
        address royaltyRecipient;
        uint96 royaltyFee; // out of 10000 (e.g., 500 = 5%)
        bool active;
    }
    
    mapping(uint256 => Listing) public listings;
    
    event Minted(uint256 indexed tokenId, address indexed owner, string tokenURI);
    event Listed(uint256 indexed tokenId, address indexed seller, uint256 price, address royaltyRecipient, uint96 royaltyFee);
    event Purchased(uint256 indexed tokenId, address indexed buyer, address indexed seller, uint256 price);
    
    constructor(address _feeRecipient) ERC721("RoyaltyNFT", "RNFT") Ownable(msg.sender) {
        tokenCounter = 0;
        feeRecipient = _feeRecipient;
    }
    
    function mintNFT(string memory tokenURI) public returns (uint256) {
        tokenCounter++;
        uint256 newTokenId = tokenCounter;
        _safeMint(msg.sender, newTokenId);
        _setTokenURI(newTokenId, tokenURI);
        emit Minted(newTokenId, msg.sender, tokenURI);
        return newTokenId;
    }
    
    function listNFT(
        uint256 tokenId,
        uint256 price,
        address royaltyRecipient,
        uint96 royaltyFee
    ) public {
        require(ownerOf(tokenId) == msg.sender, "Only owner can list");
        require(price > 0, "Price must be greater than zero");
        require(royaltyFee <= 1000, "Royalty too high (>10%)");
        
        listings[tokenId] = Listing(msg.sender, price, royaltyRecipient, royaltyFee, true);
        approve(address(this), tokenId); // Approve marketplace
        
        emit Listed(tokenId, msg.sender, price, royaltyRecipient, royaltyFee);
    }
    
    function buyNFT(uint256 tokenId) public payable {
        Listing memory item = listings[tokenId];
        require(item.active, "Listing inactive");
        require(msg.value >= item.price, "Insufficient payment");
        
        uint256 royaltyAmount = (msg.value * item.royaltyFee) / 10000;
        uint256 feeAmount = (msg.value * marketplaceFee) / 10000;
        uint256 sellerAmount = msg.value - royaltyAmount - feeAmount;
        
        // Payouts
        payable(item.royaltyRecipient).transfer(royaltyAmount);
        payable(item.seller).transfer(sellerAmount);
        payable(feeRecipient).transfer(feeAmount);
        
        // Transfer ownership
        _transfer(item.seller, msg.sender, tokenId);
        listings[tokenId].active = false;
        
        emit Purchased(tokenId, msg.sender, item.seller, msg.value);
    }
}
