## Hopeverse NFT Suit on SUI Blockchain
Project that manage and utilize NFT for game in Hopeverse. Support both Multitoken (ERC1155) standard and Individual Token (ERC721) standard

[<img src="https://lohnft.com/img/HopeverseNFTPhase_1.png" width="50%">](https://www.youtube.com/watch?v=d2ovNTW_Lao "See Hopeverse NFT Phase 1")

## Fundamental Modules
 + [Multi Token (ERC1155)](https://github.com/sukrit1234/HopeverseNFTSuit-SUI/tree/main/erc1155) : same as ethereum standard erc1155 use for game items such as Weapon,Cosmetics,Season Pass,Key,Ticket etc.
 + [Individual Token (ERC721)](https://github.com/sukrit1234/HopeverseNFTSuit-SUI/tree/main/erc721) : same as ethereum standard erc721 use for individual entity for game such as Pets,Vehicle,Character Setting,Player State etc.

## Add-On for Multi Token Modules
Multi Token has some add-on to improve utility of [ERC1155 Module](https://github.com/sukrit1234/HopeverseNFTSuit-SUI/tree/main/erc1155)
  + [Multi Token Mint](https://github.com/sukrit1234/HopeverseNFTSuit-SUI/tree/main/multitoken_mint) : Add-on that add whitelist minting capability to erc1155 (address whitelisting and charge mint fee) and can any sui::Coin as mint fee. (including SUI)
  + [Multi Token Craft](https://github.com/sukrit1234/HopeverseNFTSuit-SUI/tree/main/multitoken_craft) : Add-on for create craft template and crafting ability on erc1155, Term "Craft" mean burn multiple input items and mint multiple output items. example use woods and line iron to create wall.
  + [Multi Token Forge](https://github.com/sukrit1234/HopeverseNFTSuit-SUI/tree/main/multitoken_forge) : Add-on for create forge template and forging ability on erc1155, Term "Forge" mean melt down (burn) low level of items and forge better level of that items. example use many woods to get plank.

## Add-On for Individual Token Modules
Individual Token has some add-on to improve utility of [ERC721 Modeule](https://github.com/sukrit1234/HopeverseNFTSuit-SUI/tree/main/erc721)
 + [Erc721 Mint](https://github.com/sukrit1234/HopeverseNFTSuit-SUI/tree/main/multitoken_mint) : Add-on that add whitelist minting capability to erc721 (address whitelisting and charge mint fee) and can any sui::Coin as mint fee. (including SUI)

## Add-On for sui::coin module
 + [Faucetable](https://github.com/sukrit1234/HopeverseNFTSuit-SUI/tree/main/faucetable) : Add-on that add ability to request and refill faucet for any sui::coin.


## Use Case Module
Module just usecase for Fundamental and add-on modules
+ [Hope Token](https://github.com/sukrit1234/HopeverseNFTSuit-SUI/tree/main/hopetoken) : sui::coin that use as governance token and operation fee in Hopeverse.
+ [Hopeverse Genesis](https://github.com/sukrit1234/HopeverseNFTSuit-SUI/tree/main/hopeversegenesis) : Genesis collection of game items in Hopeverse implement from [Multi Token (ERC1155)](https://github.com/sukrit1234/HopeverseNFTSuit-SUI/tree/main/erc1155) module.
+ [Hopeverse Genesis Pets](https://github.com/sukrit1234/HopeverseNFTSuit-SUI/tree/main/hopeversegenesispet) : Genesis collection of Pets in Hopeverse implement from [Individual Token (ERC721)](https://github.com/sukrit1234/HopeverseNFTSuit-SUI/tree/main/erc721) Module
