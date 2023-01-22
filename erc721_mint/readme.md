## ERC721 Mint Module
It's compose with 3 modules. Functional on erc1155 module likely with sui::Coin<T> but implement along ethereum ERC1155 Standard.

 + **erc721_whitelist** : Module that define whitelists such as set name,description,token quota,token price.
 + **erc721_whitelistable** : Allow general user can mint erc721 token (NFT) , In generally admin (erc721::erc721::CollectionCapability object owner)
