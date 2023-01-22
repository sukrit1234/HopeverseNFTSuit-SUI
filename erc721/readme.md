## ERC721 Module (Individual Token)
It's compose with 3 modules. Functional on erc1155 module likely with sui::Coin<T> but implement along ethereum ERC1155 Standard.

 + **erc721** : main module for erc721 implementation
 + **erc721_metadata** : module that define Metadata foreach erc721 token with read and write accessor for ERC721Metadata, because sui::erc721_metadata is lack of write accessor so need to fork this version
 + **pay** : module that modify from sui::Coin<T> but use for erc721::erc721::ItemBox<T>


## ERC721 important methods
 + **create_collection<T: drop>(...)**
It's very similar functional like create_currency on sui::coin module. It's will create
    + **CollectionMetadata<T>** metadata for collection including name , symbol , description , icon_url,capability_object_id,collection_object_id , It's sui move shared object.   
    + **CollectionCapability<T>** similar **TreasureCap<T>** on sui::coin - Admin or module publisher owned this object. and change transfer by change_owner.
    + **Collection<T>** shared object that hold deinition of each token (item) in collection.
+ other function is self explanation. and you can see use case in [Hopeverse Genesis Pets](https://github.com/sukrit1234/HopeverseNFTSuit-SUI/tree/main/hopeversegenesispet)
